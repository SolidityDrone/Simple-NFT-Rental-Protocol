// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;
   
    /*
    *   THIS CODE IS NOT MEANT FOR PRODUCTION IN THIS STATE AS IT REPRESENT A VERY GENERIC ERC4907
    *   AND MAKES USES OF A DIFFERENT ERC4907 IMPLEMENTATION TO EXPLORE A DIFFERENT RENTAL SOLUTION
    *   
    */
import "./IERC4907.sol";
import "./ERC4907.sol";
contract  Collection is ERC4907 {
    
    uint256 idCount;
    constructor(string memory name_, string memory symbol_)
    ERC4907(name_,symbol_)
    {   
          idCount = 1;
    }
  
    function mint() public returns (bool){
        _safeMint(msg.sender, idCount);
        idCount++;
        return true;
    }


   


}