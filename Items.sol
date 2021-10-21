pragma solidity ^0.5.0;

import "./math/SafeMath.sol";
import "./utils/Pauseable.sol";
import "./access/Ownable.sol";

contract Items is Ownable, Pauseable{

    using SafeMath for uint;
    /* Sale status Enum used by Sale ,with 3 states
        Onsale
        Soldout
        Rejected
    */
    enum SaleStatus { OnSale, Deactivated, Rejected }

    struct Item {
        string name;
        string description;
        uint price;
        uint stock;
        uint timestamp;
        SaleStatus saleStatus;
        address payable seller;
    }

    mapping (string => Item) private items;

    event AddItem(address seller, string itemId , uint stock, uint price);
    event UpdateItem(address seller, string itemId , uint stock, uint price);
    event RejectedItem(string itemId);
    event DeactivatedItem(string itemId);

    modifier isSeller(string memory _itemId){
        _;
        require(items[_itemId].seller != address(0) && items[_itemId].seller == msg.sender, "should be the seller to process forward");
    }

    /// @notice Add item
    /// @dev Emits LogAddItem
    /// @param _itemId id of the item
    /// @param _name name of the item
    /// @param _description description of the item
    /// @param _price price of the item
    /// @param _stock number of the item to sell
    /// @return true if item is created
    function addItem(string memory _itemId,string memory _name, string memory _image, string memory _description, uint _price, uint _stock)
    public
    whenNotPaused()
    returns(bool){
        require(_stock>0, 'Number of items should be atleast 1');
        require(_price>0, 'Price of items cannot be atleast 0');
        Item memory newItem;
        newItem.name = _name;
        newItem.description = _description;
        newItem.price = _price;
        newItem.stock = _stock;
        newItem.seller = msg.sender;
        newItem.timestamp = now;
        newItem.saleStatus = SaleStatus.OnSale;
        items[_itemId] = newItem;
        emit AddItem(msg.sender, _itemId, _stock, _price);
        return true;
    }

    /// @notice Get am item based on item id
    /// @param _itemId id of the item to fetch
    /// @return id, name, description , price , number of Items left, timestamp and seller address of the item
    function getItem(string memory _itemId)
    public
    view
    returns (string memory id, string memory name, string memory description, uint price, uint stock, address seller, uint timestamp) {
        id = _itemId;
        name = items[_itemId].name;
        price = items[_itemId].price;
        description = items[_itemId].description;
        stock = items[_itemId].stock;
        seller = items[_itemId].seller;
        timestamp = items[_itemId].timestamp;
        return (id, name, image, description, price, stock, seller, timestamp);
    }

    /// @notice Update item
    /// @dev Emits LogUpdateItem
    /// @dev Need to be seller of the item to update
    /// @param _itemId id of the item
    /// @param _name name of the item
    /// @param _description description of the item
    /// @param _price price of the item
    /// @param _stock number of the item to sell
    /// @return true if item is udpated
    function updateItem(string memory _itemId, string memory _name, string memory _description, uint _price, uint _stock)
    public
    whenNotPaused()
    isSeller(_itemId)
    returns(bool){
        require(_stock>0, 'Number of items should be atleast 1');
        require(_price>0, 'Price of items cannot be atleast 0');
        items[_itemId].name = _name;
        items[_itemId].image = _image;
        items[_itemId].description = _description;
        items[_itemId].price = _price;
        items[_itemId].stock = _stock;
        emit UpdateItem(msg.sender, _itemId, _stock, _price);
        return true;
    }
    /// @notice Update item
    /// @dev Emits LogUpdateItem
    /// @dev Need to be seller of the item to update
    /// @param _itemId id of the item
    function deactivatedItem(string memory _itemId)
    public
    whenNotPaused()
    isSeller(_itemId)
    returns(bool){
        items[_itemId].saleStatus = SaleStatus.Deactivated;
        emit DeactivatedItem(itemId);
        return true;
    }

    /// @notice Rejected item
    /// @dev Emits RejectedItem
    /// @dev rejected item by owner cause break the rules
    /// @param _itemId id of the item
    function rejectedItem(string memory _itemId)
    public
    onlyOwner{
        items[_itemId].saleStatus = SaleStatus.Rejected;
        emit RejectedItem(itemId);
        return true;
    }

}