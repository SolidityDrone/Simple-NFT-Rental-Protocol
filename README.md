# Abstract 

Few months ago EIP4907 has been flagged at final status at ethereum-magicians. ERC4907 adds the User role extending ERC721
Tho make use of it I ran this simple project involving ERC4907 tokens and an intermediary contract, sort of marketplace, to handle rentals 
The goal is to offer a different implementation as for what was given in the official EIP in order to make things simpler for intermediary contracts, thus 
saving gas in the ecosystem.
A problem I can see with the original implementation is that the user "rights" are not protected from being "rugged". So it cleary needs an intermediary
to hold the NFT. This way the owner can't sell or transfer usership in the meanwhile. *But requiring a custodiary approach requires more transactions, therefore more gas*
In my approach there's no neeed for a custody, the usership is granted and guaranteed untill its expiration date. Meanwhile the owner can sell or transfer the ownership.
The only problem with this would on the side of eventual marketplaces not noticing buyers of a "timelock" over usership. This is easy handled by a big marketplace as it could easy 
flag an item as "dangerous buy".


# A look at Code

Original ERC4907 implementation 
```
// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IERC4907.sol";

contract ERC4907 is ERC721, IERC4907 {
    struct UserInfo 
    {
        address user;   // address of user role
        uint64 expires; // unix timestamp, user expires
    }

    mapping (uint256  => UserInfo) internal _users;

    constructor(string memory name_, string memory symbol_)
     ERC721(name_, symbol_)
     {
     }
    
    /// @notice set the user and expires of an NFT
    /// @dev The zero address indicates there is no user
    /// Throws if `tokenId` is not valid NFT
    /// @param user  The new user of the NFT
    /// @param expires  UNIX timestamp, The new user could use the NFT before expires
    function setUser(uint256 tokenId, address user, uint64 expires) public virtual{
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC4907: transfer caller is not owner nor approved");
        UserInfo storage info =  _users[tokenId];
        info.user = user;
        info.expires = expires;
        emit UpdateUser(tokenId, user, expires);
    }

    /// @notice Get the user address of an NFT
    /// @dev The zero address indicates that there is no user or the user is expired
    /// @param tokenId The NFT to get the user address for
    /// @return The user address for this NFT
    function userOf(uint256 tokenId) public view virtual returns(address){
        if( uint256(_users[tokenId].expires) >=  block.timestamp){
            return  _users[tokenId].user;
        }
        else{
            return address(0);
        }
    }

    /// @notice Get the user expires of an NFT
    /// @dev The zero value indicates that there is no user
    /// @param tokenId The NFT to get the user expires for
    /// @return The user expires for this NFT
    function userExpires(uint256 tokenId) public view virtual returns(uint256){
        return _users[tokenId].expires;
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC4907).interfaceId || super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override{
        super._beforeTokenTransfer(from, to, tokenId);

        if (from != to && _users[tokenId].user != address(0)) {
            delete _users[tokenId];
            emit UpdateUser(tokenId, address(0), 0);
        }
    }
} 
```
( ERC4907 https://github.com/ethereum/EIPs/blob/master/EIPS/eip-4907.md )

This is the implementation of the IERC4907 that is presented on the paper. 
In my understandings this implementation has to be considered ideal for DoubleProtocol, which is a rental protocol for nfts.

Generally speaking I didn't find this implementation good enough and tried a slightly different approach:


```
  function setUser(uint256 tokenId, address user, uint256 expires) public virtual  override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC4907: transfer caller is not owner nor approved");
        require(userOf(tokenId) == ownerOf(tokenId), "ERC4907: user can't be set before expiration");   
        UserInfo storage info =  _users[tokenId];
        info.user = user;
        info.expires = expires;
        emit UpdateUser(tokenId, user, expires);
    }
```
Changed setUser order to make the user not able to setUsership while the usership is granted (rented).


```
 function userOf(uint256 tokenId)public view virtual override returns(address){
        if( uint256(_users[tokenId].expires) >=  block.timestamp){
            return  _users[tokenId].user;
        }
        else{
            return address(ownerOf(tokenId));
        }
    }
```
Here in userOf() function I changed the owner to be returned as user when the usership is expired. 
These 2 lines of code make a huge difference in preserving users rights. 
Doing so we save tons of gas by just cutting the numbers of interactions.
If the Lender makes a setApprovalForAll transaction, every other rental order will require only 1 tx. Opposed to 2 for custodiary solutions



# The folder

This folder is a foundry project (https://github.com/foundry-rs/foundry)


If you have this framework installed on your system you can run tests

```
forge test
```


