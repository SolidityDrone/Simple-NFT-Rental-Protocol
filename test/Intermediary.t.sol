// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "std/test.sol";

import "../src/Collection.sol";
import "../src/Intermediary.sol";

contract OwnerUpOnlyTest is Test {
    Collection public col;
    Intermediary public mp;

    address[] acc = 
        [
            0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
            0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db, 
            0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
        ];


    function setUp() public {
        mp = new Intermediary();
        col = new Collection("erc","erc");
        vm.prank(address(acc[0]));
        vm.warp(1);
        col.mint();
        // Giving 100 wei to every account in the list acc
        for (uint i = 0; i <acc.length; i++){
             vm.deal(acc[i], 100);
        }
    }
    
    function collection_Mint() public {
        vm.prank(address(acc[0]));
        assertEq(col.ownerOf(1), address(acc[0]));
    }

    function collection_SetUser() public {
        vm.prank(address(acc[0]));
        //set the user to Acc2, expires at 3 
        col.setUser(1, acc[2], 3);
        vm.warp(2);
        vm.expectRevert("ERC4907: user can't be set before expiration");
        vm.prank(address(acc[0])); 
        //Setting user while usership is not expired will revert
        col.setUser(1, acc[1], 4);
    }

    function collection_SetUserFromApproved() public {
        //Current Block.Timestamp = 1;
        vm.warp(1);
        //Acc0 sets approval for Acc1
        vm.prank(address(acc[0])); 
        col.setApprovalForAll(acc[1], true);
        //Check Acc1 has approval of Acc1
        vm.prank(address(acc[1]));
        assertTrue(col.isApprovedForAll(acc[0], acc[1]), "Address has no approval");
        //Acc1 set user to Acc2
        vm.prank(address(acc[1]));    
        col.setUser(1, acc[2], 500);
        //Expect user to be Acc2
        assertEq(col.userOf(1), address(acc[2]));
        //Warp to expiration date
        vm.warp(501);
        //Expect user to be owner
        assertEq(col.userOf(1), col.ownerOf(1));
    }
    function intermediary_testCreateRental()public {
        uint256 _tokenId = 1;
        uint256 _cost = 1;
        uint256 _rentalLimit = 1000;
        //  Calling SetForRental from non owner should revert
        vm.prank(address(acc[1])); 
        col.setApprovalForAll(address(mp), true);
        vm.expectRevert("ERC4907: Not owner");
        mp.SetForRental(address(col), _tokenId, 1, _cost);
        //  Calling SetApprovalForAll and SetForRental,
        //  expecting to revert when rental limit is < block.timestamp
        vm.prank(address(acc[0])); 
        col.setApprovalForAll(address(mp), true);
        vm.prank(address(acc[0])); 
        vm.expectRevert("RentalLimit MUST be greater than current block.timestamp");
        mp.SetForRental(address(col), _tokenId, 0, _cost);
        vm.prank(address(acc[0])); 
        mp.SetForRental(address(col), _tokenId, _rentalLimit, _cost);
        //  Asserting struct values
        bytes32 requestId = keccak256(abi.encodePacked(address(col), _tokenId));
        assertEq(mp.getRentalInfo(requestId).tokenId, _tokenId, "Incorrect token stored in struct");
        assertEq(mp.getRentalInfo(requestId).lender, acc[0], "Incorrect lender stored in struct");
        assertEq(mp.getRentalInfo(requestId).rentalLimit, _rentalLimit, "Incorrect rental limit stored in struct");
        assertEq(mp.getRentalInfo(requestId).cost, _cost, "Incorrect rental limit stored in struct");
        assertEq(mp.getRentalInfo(requestId).contractAddress, address(col), "Incorrect contract address limit stored in struct");
        // Acc0 may call SetForRental to update values unless the usership is rented
        vm.prank(address(acc[0])); 
        mp.SetForRental(address(col), _tokenId, _rentalLimit*2, _cost*2);
        assertEq(mp.getRentalInfo(requestId).tokenId, _tokenId, "Incorrect token stored in struct");
        assertEq(mp.getRentalInfo(requestId).lender, acc[0], "Incorrect lender stored in struct");
        assertEq(mp.getRentalInfo(requestId).rentalLimit, _rentalLimit*2, "Incorrect rental limit stored in struct");
        assertEq(mp.getRentalInfo(requestId).contractAddress, address(col), "Incorrect contract address limit stored in struct");
        // When the item is rented, calls to this function will revert
        // This can happen both if the user is set on or off contract
        vm.prank(address(acc[0])); 
        col.setUser(1, acc[1], 10);
        vm.prank(address(acc[0])); 
        vm.expectRevert("ERC4907: Usership already on rental");
        mp.SetForRental(address(col), _tokenId, 0, _cost);
        assertEq(col.ownerOf(1), address(acc[0]));
        vm.prank(address(acc[0])); 
    }


    function intermediary_BorrowAndCheckUsership() public {
       
        uint256 _tokenId = 1;
        uint256 _cost = 1;
        uint256 _rentalLimit = 1000;
        bytes32 requestId = keccak256(abi.encodePacked(address(col), _tokenId));
        //Acc0 sets ApprovalForAll to contract Mp and set rental
        vm.prank(address(acc[0])); 
        col.setApprovalForAll(address(mp), true);
        vm.prank(address(acc[0])); 
        mp.SetForRental(address(col), _tokenId, _rentalLimit, _cost);

        //Acc1 calls payable function Borrow with correct value
        vm.prank(address(acc[1])); 
        mp.Borrow{value: 10}(address(col), _tokenId, 10);
        vm.clearMockedCalls();
        vm.prank(address(acc[1])); 
        //expect struct  to be up to date and user to be correct
        assertEq(mp.getRentalInfo(requestId).borrower, address(acc[1]), "Incorrect token stored in struct");
        assertEq(mp.getRentalInfo(requestId).rentalExpires, block.timestamp + 10, "Incorrect token stored in struct");
        assertEq(col.userOf(_tokenId), acc[1], "Incorrect token stored in struct");
        //Acc2 makes the same call after Acc1, expect revert with message
        vm.prank(address(acc[2])); 
        vm.expectRevert("Currently on rental");
        mp.Borrow{value: 10}(address(col), _tokenId, 10);
        vm.clearMockedCalls();
        //Owner try to change rental, expect revert with message
        vm.prank(address(acc[0])); 
        vm.expectRevert("ERC4907: Usership already on rental");
        mp.SetForRental(address(col), _tokenId, 0, _cost);
        assertEq(col.ownerOf(1), address(acc[0]));
        // Block.timestamp => 998
        vm.warp(998);
        // User is now expected to be the Owner
        assertEq(col.userOf(_tokenId), col.ownerOf(_tokenId), "Incorrect token stored in struct");
        //Acc1 makes a call where rental expires is greater than limit, expect revert with message
        vm.prank(address(acc[1])); 
        vm.expectRevert("The rental period cannot exceed rentalLimit, this order may be expired");
        mp.Borrow{value: 10}(address(col), _tokenId, 10);
        vm.clearMockedCalls();
       
        //Acc0 makes the same call, expect revert with message
        vm.prank(address(acc[0])); 
        vm.expectRevert("Can't lend to owner");
        mp.Borrow{value: 10}(address(col), _tokenId, 10);
        vm.clearMockedCalls();
        //Acc1 makes now a call where rental expiration is lesser than limit.
        vm.prank(address(acc[1])); 
        mp.Borrow{value: 1}(address(col), _tokenId, 1);
        vm.clearMockedCalls();
        //Check eth balances are up to date
        assertEq(address(acc[1]).balance, 89);  
        assertEq(address(acc[0]).balance, 111);  
         
    }
    function intermediary_testOwnershipTransferCase() public {
        uint256 _tokenId = 1;
        uint256 _cost = 1;
        uint256 _rentalLimit = 2000;
        bytes32 requestId = keccak256(abi.encodePacked(address(col), _tokenId));
        //Acc0 sets ApprovalForAll to contract Mp and set rental
        vm.prank(address(acc[0])); 
        col.setApprovalForAll(address(mp), true);
        vm.prank(address(acc[0])); 
        mp.SetForRental(address(col), _tokenId, _rentalLimit, _cost);
        
        //Acc1 calls payable function Borrow with correct value
        vm.prank(address(acc[1])); 
        mp.Borrow{value: 10}(address(col), _tokenId, 10);
        vm.clearMockedCalls();
 
        //Acc0 transfer ownership to Acc2
        vm.prank(address(acc[0])); 
        col.transferFrom(acc[0], acc[2], 1);
        //Acc2 try update the rental calling setApprovalForAll while on rent, expect revert with message
        vm.prank(address(acc[2])); 
        col.setApprovalForAll(address(mp), true);
        vm.prank(address(acc[2])); 
        vm.expectRevert("ERC4907: Usership already on rental");
        mp.SetForRental(address(col), _tokenId, _rentalLimit, _cost);

        assertEq(col.ownerOf(1), address(acc[2]));
        assertEq(col.userOf(1), address(acc[1]));
        // Block.timestamp => 2011
        vm.warp(2011);
        //Acc1 rental expires, so user is owner
        assertEq(col.userOf(1), address(acc[2]));

    }
}