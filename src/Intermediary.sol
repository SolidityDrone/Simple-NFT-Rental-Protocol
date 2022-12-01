// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "./IERC4907.sol";

contract Intermediary {

    event RentalCreated( address indexed lender,  address indexed contractAddress, uint256 tokenId);
    event Borrowed(address indexed borrower, bytes32 indexed rentalById, uint256 rentalExpires);

    /*  @dev  requestId => rentalInfo */  
    mapping(bytes32=>rentalInfo) internal rentalById;
    /*  @dev  `rentalLimit` is when the offer expires, 
    *   `rentalExpires` is when the current usership expires */    
    struct rentalInfo {
        address contractAddress;    
        address lender;             
        address borrower;
        uint256 tokenId;
        uint256 rentalLimit;
        uint256 rentalExpires;
        uint256 cost;
    }

 
    function getRentalId(address contractAddress, uint256 tokenId) internal pure returns (bytes32){
        return keccak256(abi.encodePacked(contractAddress, tokenId));
    }
    /// @notice get the rental infos by rental id
    /// @dev The zero address indicates there is no user
    /// Throws if `tokenId` is not valid NFT
    /// @param rentalId  The new user of the NFT
    function getRentalInfo(bytes32 rentalId) external view returns (rentalInfo memory){
        return rentalById[rentalId];
    }
    /// @notice set an item for rental, returns true 
    /// @dev The zero address indicates there is no user
    /// Throws if `_setForRental()` is reverted;
    /// @return The success of the functionn
    function SetForRental(address contractAddress, uint256 tokenId, uint256 rentalLimit, uint256 cost) public virtual returns (bool) {
        _setForRental(contractAddress, tokenId, rentalLimit, cost);
        return true;
    }
  
    /* @notice set an item for rental, returns true 
     * @dev this is the internal function that is called by SetForRental
     * requires the message.sender to be the owner of the `tokenId` at `contractAddress`
     * the ERC4907 at `contractAddress` MUST NOT be already on rental and `rentalLimit` should be 
     * greater than current time.
     * 
     * To prevent useless transactions to get in, approval or approvalForAll is required
     *
     * `rentalId` is the byte32 of kekkack256(abi.encodePacked(`contractAddress`, `tokenId`)) to easily map orders in `rentalById[bytes32]`
     * The rentalInfo struct at `rentalById[bytes32]` is updated with params and emits `RentalCreated()`
     */
    function _setForRental(address contractAddress, uint256 tokenId, uint256 rentalLimit, uint256 cost) internal virtual {
        require(IERC4907(contractAddress).ownerOf(tokenId) == msg.sender, "ERC4907: Not owner");
        require(IERC4907(contractAddress).userExpires(tokenId) < block.timestamp, "ERC4907: Usership already on rental");
        require(rentalLimit > block.timestamp, "RentalLimit MUST be greater than current block.timestamp");
        require(IERC4907(contractAddress).isApprovedForAll(msg.sender, address(this)) == true  || IERC4907(contractAddress).getApproved(tokenId) == address(this), "Need to be approved first!");
        bytes32 rentalId = getRentalId(contractAddress, tokenId);
        rentalInfo storage rnt = rentalById[rentalId];
        rnt.contractAddress = contractAddress;
        rnt.lender = msg.sender;
        rnt.tokenId = tokenId;
        rnt.cost = cost;
        rnt.rentalLimit = rentalLimit;
        emit RentalCreated(msg.sender, contractAddress, tokenId);
    }



     /* @notice borrowNft
     * @dev The value of the call must be equal to the `cost` 
     * thus the balance of the msg.sender must be equal or greater than calculated cost
     * calls internal function `_borrow()` and returns wheter the function succeded
     */
    function Borrow(address contractAddress, uint256 tokenId, uint256 rentalPeriod) public virtual payable returns  (bool) {
        bytes32 rentalId = getRentalId(contractAddress, tokenId);
        uint256 cost = rentalPeriod * rentalById[rentalId].cost;
        require(address(msg.sender).balance > (cost), "Not enough ether to complete the tx");
        require(msg.value == cost, "Incorrect amount");
        return _borrow(rentalId,rentalPeriod);
    }


    /* @notice _borrowNft internal function
     * @dev initializes `rentalInfo storage rnt`. The rnt.contractAddress should not be equal
     * address(0), meaning the order dosen't exist.
     * This also requires ERC4907 to not be on rental or any redundant operation like self lending.
     * The rental period cannot exceed `rentalLimit`.
     *
     * Updated `rnt` and `setUser` to be the msg.sender 
     * Finally executes an ether transfer via `call{value:}`, this is required to succed before return 
     * true to `Borrow()` function. 
     */
    function _borrow(bytes32 rentalId, uint256 rentalPeriod) internal  virtual returns(bool) {
        rentalInfo storage rnt = rentalById[rentalId];
        
        require(rnt.contractAddress != address(0), "Invalid request");
        uint256 expirationDate = rentalPeriod + block.timestamp;
        uint256  cost = rentalPeriod * rentalById[rentalId].cost;
        require(IERC4907(rnt.contractAddress).userExpires(rnt.tokenId) < block.timestamp, "Currently on rental");
        require(IERC4907(rnt.contractAddress).ownerOf(rnt.tokenId) != msg.sender, "Can't lend to owner");
        require(expirationDate <= rnt.rentalLimit, "The rental period cannot exceed rentalLimit, this order may be expired");
        rnt.borrower = msg.sender;
        rnt.rentalExpires = expirationDate;
        IERC4907(rnt.contractAddress).setUser(rnt.tokenId, msg.sender, expirationDate);
        emit Borrowed(msg.sender, rentalId, expirationDate);

        (bool sent, bytes memory data) = (rnt.lender).call{value: (cost) *1 wei}("");
        require(sent, "Failed to send Ether");
        return true;
    }

    

}