pragma solidity ^0.5.0;

import "./Items.sol";
import "./math/SafeMath.sol";
import "./utils/Pauseable.sol";
import "./access/Ownable.sol";

contract SalePlace is Items, Ownable, Pausable{

  using SafeMath for uint;
  /* Status Enum used by ItemInvoice ,with 4 states
    Processing
    Shipped
    Received
    Refunded
  */
  enum Status { Processing, Shipped, Received, Refunded }

  struct ItemInvoice{
    string itemId;
    uint quantity;
    uint amountPaid;
    Status status;
    uint timestamp;
    address payable buyer;
  }

  mapping (string => ItemInvoice) private itemsSold;

  modifier isBuyer(string memory _itemId){
    _;
    require(itemsSold[_itemId].buyer != address(0) && itemsSold[_itemId].buyer == msg.sender, "should be a buyer to process forward");
  }

  event BuyItem(address buyer, string invoiceId, uint quantity);
  event Shipped(address seller, string invoiceId, string itemId);
  event Received(address buyer, string invoiceId, string itemId);
  event Refund(address seller, address buyer, string invoiceId, string itemId, uint amountRefunded);

  /// @notice Trade logic called when items are purchased by a user
  /// @param _itemId id of the item to fetch
  /// @param _quantity number of the items purchased
  /// @dev the function will trade amount from buyer to seller , also any left over amount will be transfered to buyer itself
  modifier trade (string memory _itemId, uint _quantity)  {
    _;
    uint totalAmount = _quantity.mul(items[_itemId].price);
    require(msg.value >= totalAmount, 'Amount less than required');

    uint amountToRefund = msg.value.sub(items[_itemId].price);
    if(amountToRefund>0){
      msg.sender.transfer(amountToRefund); // transfer left over to buyer
    }
    items[_itemId].seller.transfer(items[_itemId].price); // send the money to seller
  }

  /// @notice Get item purcahsed details of the request user mapping for given item
  /// @param _invoiceId  invoice id of the item sold to fetch 
  /// @return itemId, invoiceId, number of Items sold , status, timestamp, buyer address & amount paid
  function getItemSold(string memory _invoiceId)
  public 
  view 
  isBuyer(_invoiceId)
  returns (string memory itemId, string memory invoiceId, uint quantitySold, Status status, address buyer, uint timestamp, uint amountPaid) {
    itemId = itemsSold[_invoiceId].itemId;
    invoiceId = _invoiceId;
    quantitySold = itemsSold[_invoiceId].quantitySold;
    status = itemsSold[_invoiceId].status;
    buyer = itemsSold[_invoiceId].buyer;
    timestamp = itemsSold[_invoiceId].timestamp;
    amountPaid = itemsSold[_invoiceId].amountPaid;
    return (itemId, invoiceId, quantitySold, status, buyer, timestamp, amountPaid);
  }

  /// @notice Function to buy items
  /// @dev Emits BuyItem
  /// @dev Amount paid more than required will be refunded
  /// @param _itemId id of the item
  /// @param _invoiceId id of the invoice item sold
  /// @param _quantity number of the item to buy
  /// @return true if items are bought
  function buyItem(string memory _itemId, string memory _invoiceId, uint _quantity)
  public
  payable
  whenNotPaused()
  trade(_itemId,_quantity)
  returns(bool){
    require(_quantity>0, 'Number of items should be atleast 1');
    require(items[_itemId].stock - _quantity >= 0, 'Out of stock');

    itemsSold[_invoiceId].status = Status.Processing;
    itemsSold[_invoiceId].quantitySold = _quantity;
    itemsSold[_invoiceId].buyer = msg.sender;
    itemsSold[_invoiceId].timestamp = now;
    itemsSold[_invoiceId].itemId = _itemId;
    itemsSold[_invoiceId].amountPaid = _quantity.mul(items[_itemId].price);

    items[_itemId].stock.sub(_quantity);

    emit BuyItem(msg.sender, _itemId, _quantity);

    return true;
  }

  /// @notice Function called by seller to set item status to shipped
  /// @dev Emits Shipped
  /// @dev Needs to be seller of the itemto access the function
  /// @param _invoiceId id of the invoice id of item sold
  /// @return true if items is udpated to shipped status
  function shipItem(string memory _invoiceId)
  public
  returns(bool){
    require(itemsSold[_invoiceId].status == Status.Processing, 'Item already shipped');
    require(items[itemsSold[_invoiceId].itemId].seller == msg.sender, 'Action restricted to seller only');
    itemsSold[_invoiceId].status = Status.Shipped;
    emit Shipped(msg.sender, _invoiceId, itemsSold[_invoiceId].itemId);
    return true;
  }

  /// @notice Function called by buyer to set item status to received
  /// @dev Emits Received
  /// @dev Needs to be buyer of the item to access the function
  /// @param _invoiceId id of the invoice id of item sold
  /// @return true if items is udpated to received status
  function receiveItem(string memory _invoiceId)
  public
  isBuyer(_invoiceId)
  returns(bool){
    require(itemsSold[_invoiceId].status == Status.Shipped , 'Item not yet shipped');
    require(itemsSold[_invoiceId].buyer == msg.sender, 'Action restricted to buyer only');
    itemsSold[_invoiceId].status = Status.Received;
    emit Received(msg.sender, _invoiceId, itemsSold[_invoiceId].itemId);
    return true;
  }

  /// @notice Function called by seller to refund for the item
  /// @dev Emits Refund
  /// @dev Needs to be seller of the item to access the function
  /// @dev Amount is transfered from seller account to buyer account , any left over paid will transfered to the seller itself
  /// @param _invoiceId id of the invoice id of item sold
  /// @return true if refund is successfull
  function refundItem(string memory _invoiceId)
  public
  payable
  returns(bool){
    string memory itemId = itemsSold[_invoiceId].itemId;
    require(items[itemId].seller == msg.sender, 'Action restricted to seller only');

    require(msg.value >= itemsSold[_invoiceId].amountPaid, 'Amount less than required');
    require(itemsSold[_invoiceId].amountPaid > 0, 'Total amount to refund should be greater than zero');

    itemsSold[_invoiceId].buyer.transfer(itemsSold[_invoiceId].amountPaid); // transfer to buyer

    uint amountLeftOver = msg.value.sub(itemsSold[_invoiceId].amountPaid);
    
    if(amountLeftOver>0){
      items[itemId].seller.transfer(amountLeftOver); // transfer any left over to seller
    }
    itemsSold[_invoiceId].status = Status.Refunded;
    
    emit Refund(msg.sender, itemsSold[_invoiceId].buyer, _invoiceId, itemId, itemsSold[_invoiceId].amountPaid);
    return true;
  }
}