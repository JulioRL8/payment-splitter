// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {PaymentSplitter} from "../src/PaymentSplitter.sol";
import {TestBase} from "./TestBase.sol";

contract PaymentSplitterTest is TestBase {
    PaymentSplitter private splitter;
    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);

    function setUp() public {
        vm.deal(address(this), 10 ether);
        splitter = new PaymentSplitter(ALICE, BOB, 6000);
    }

    function testRejectsZeroFirstPayee() public {
        vm.expectRevert(PaymentSplitter.InvalidPayees.selector);
        new PaymentSplitter(address(0), BOB, 6000);
    }

    function testRejectsZeroSecondPayee() public {
        vm.expectRevert(PaymentSplitter.InvalidPayees.selector);
        new PaymentSplitter(ALICE, address(0), 6000);
    }

    function testRejectsDuplicatePayees() public {
        vm.expectRevert(PaymentSplitter.InvalidPayees.selector);
        new PaymentSplitter(ALICE, ALICE, 6000);
    }

    function testRejectsZeroFirstShare() public {
        vm.expectRevert(PaymentSplitter.InvalidShare.selector);
        new PaymentSplitter(ALICE, BOB, 0);
    }

    function testRejectsFullFirstShare() public {
        vm.expectRevert(PaymentSplitter.InvalidShare.selector);
        new PaymentSplitter(ALICE, BOB, 10_000);
    }

    function testBothDepositEntryPointsCreditRemainders() public {
        vm.expectRevert(PaymentSplitter.EmptyDeposit.selector);
        splitter.deposit();
        splitter.deposit{value: 11}();
        (bool sent,) = address(splitter).call{value: 3}("");
        assertTrue(sent);

        assertEq(splitter.credit(ALICE), 7);
        assertEq(splitter.credit(BOB), 7);
        vm.prank(ALICE);
        splitter.withdraw(payable(ALICE));
        assertEq(ALICE.balance, 7);
        assertEq(splitter.credit(ALICE), 0);
        assertEq(splitter.credit(BOB), 7);
        vm.prank(BOB);
        splitter.withdraw(payable(BOB));
        assertEq(BOB.balance, 7);
        assertEq(address(splitter).balance, 0);
    }

    function testRevertedWithdrawalKeepsCredit() public {
        splitter.deposit{value: 10}();
        vm.expectRevert(PaymentSplitter.NothingToWithdraw.selector);
        splitter.withdraw(payable(ALICE));

        vm.prank(ALICE);
        vm.expectRevert(PaymentSplitter.InvalidRecipient.selector);
        splitter.withdraw(payable(address(0)));

        vm.prank(ALICE);
        vm.expectRevert(PaymentSplitter.TransferFailed.selector);
        splitter.withdraw(payable(address(this)));
        assertEq(splitter.credit(ALICE), 6);
        vm.prank(ALICE);
        splitter.withdraw(payable(BOB));
        assertEq(BOB.balance, 6);
    }

    function testFuzzSplit(uint96 rawDeposit, uint16 rawShare) public {
        uint256 depositAmount = 1 + uint256(rawDeposit);
        uint256 share = 1 + uint256(rawShare) % 9999;
        PaymentSplitter configured = new PaymentSplitter(ALICE, BOB, share);
        vm.deal(address(this), depositAmount);
        configured.deposit{value: depositAmount}();
        uint256 first = depositAmount * share / 10_000;
        assertEq(configured.credit(ALICE), first);
        assertEq(configured.credit(BOB), depositAmount - first);
    }
}
