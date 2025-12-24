//SPDX-License-Identifier:  MIT
pragma solidity ^0.8.20; 

contract Escrow{
    address public buyer;
    address public seller;
    address public arbitrator;

    uint256 public amount;
    uint256 public depositedAt;
    uint256 public timeout = 3 days; 

    enum State{
        AWAITING_PAYMENT,
        AWAITING_DELIVERY,
        AWAITING_APPROVAL,
        COMPLETE,
        DISPUTED,
        REFUNDED
        
    }
    State public currentState;

    constructor(address _seller, address _arbitrator) {
        buyer = msg.sender;
        seller = _seller;
        arbitrator = _arbitrator;
        currentState = State.AWAITING_PAYMENT;
    }

    modifier onlyBuyer(){
        require(msg.sender == buyer, "Only Buyer Allowed");
        _;
    }
    modifier onlySeller(){
        require(msg.sender == seller, "Only Seller Allowed");
        _;
    }
    modifier onlyArbitrator(){
        require(msg.sender == arbitrator, "Only Arbitrator Allowed");
        _;
    }
    modifier inState(State expectedState){
        require(currentState == expectedState, "Invalid State");
        _;
    }
    function deposit() external payable onlyBuyer inState(State.AWAITING_PAYMENT){

        require(msg.value > 0, "Must Send Eth");
        amount = msg.value;
        depositedAt = block.timestamp;
        currentState = State.AWAITING_DELIVERY;

    }
    function confirmDelivery() external onlySeller inState(State.AWAITING_DELIVERY){
        currentState = State.AWAITING_APPROVAL;
    }
    function approveRelease() external onlyBuyer inState(State.AWAITING_APPROVAL){
        currentState = State.COMPLETE;
        _safeSend(seller, amount);
    }
    function refundBuyer() external onlyBuyer inState(State.AWAITING_DELIVERY){
        require(block.timestamp >= depositedAt + timeout, "Timeout not Reached");
        currentState = State.REFUNDED;
        _safeSend(buyer, amount);
    }
    function raiseDispute() external {
        require( msg.sender == buyer || msg.sender == seller, "Not Authorized");
        currentState = State.DISPUTED;
    }
   function resolveDispute(bool releaseToSeller) external onlyArbitrator inState(State.DISPUTED){
        if(releaseToSeller){
            _safeSend(seller, amount);
        } else {
            _safeSend(buyer, amount);
        }
        currentState = State.COMPLETE;
   }
   function _safeSend(address to, uint256 value)internal{
    (bool success,) = to.call{value: value}("");
    require(success, "Eth Transfer Failed");
   }
}