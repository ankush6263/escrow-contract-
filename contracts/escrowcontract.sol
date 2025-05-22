// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Escrow Contract
 * @dev A secure escrow smart contract for trustless transactions
 * @author Your Name
 */
contract Project {
    enum EscrowState { AWAITING_PAYMENT, AWAITING_DELIVERY, COMPLETE, REFUNDED }
    
    struct EscrowTransaction {
        address buyer;
        address seller;
        address arbiter;
        uint256 amount;
        EscrowState state;
        bool buyerApproval;
        bool sellerApproval;
        uint256 createdAt;
        string description;
    }
    
    mapping(uint256 => EscrowTransaction) public escrows;
    uint256 public escrowCounter;
    
    // Events
    event EscrowCreated(uint256 indexed escrowId, address indexed buyer, address indexed seller, uint256 amount);
    event PaymentDeposited(uint256 indexed escrowId, uint256 amount);
    event DeliveryConfirmed(uint256 indexed escrowId);
    event PaymentReleased(uint256 indexed escrowId, address indexed seller, uint256 amount);
    event RefundIssued(uint256 indexed escrowId, address indexed buyer, uint256 amount);
    event DisputeResolved(uint256 indexed escrowId, address indexed winner, uint256 amount);
    
    // Modifiers
    modifier onlyBuyer(uint256 _escrowId) {
        require(msg.sender == escrows[_escrowId].buyer, "Only buyer can call this function");
        _;
    }
    
    modifier onlySeller(uint256 _escrowId) {
        require(msg.sender == escrows[_escrowId].seller, "Only seller can call this function");
        _;
    }
    
    modifier onlyArbiter(uint256 _escrowId) {
        require(msg.sender == escrows[_escrowId].arbiter, "Only arbiter can call this function");
        _;
    }
    
    modifier inState(uint256 _escrowId, EscrowState _state) {
        require(escrows[_escrowId].state == _state, "Invalid state for this operation");
        _;
    }
    
    /**
     * @dev Creates a new escrow transaction
     * @param _seller Address of the seller
     * @param _arbiter Address of the arbiter (dispute resolver)
     * @param _description Description of the transaction
     * @return escrowId The ID of the created escrow
     */
    function createEscrow(
        address _seller,
        address _arbiter,
        string memory _description
    ) external payable returns (uint256) {
        require(msg.value > 0, "Escrow amount must be greater than 0");
        require(_seller != address(0) && _arbiter != address(0), "Invalid addresses");
        require(_seller != msg.sender, "Buyer and seller cannot be the same");
        require(_arbiter != msg.sender && _arbiter != _seller, "Arbiter must be different from buyer and seller");
        
        uint256 escrowId = escrowCounter++;
        
        escrows[escrowId] = EscrowTransaction({
            buyer: msg.sender,
            seller: _seller,
            arbiter: _arbiter,
            amount: msg.value,
            state: EscrowState.AWAITING_DELIVERY,
            buyerApproval: false,
            sellerApproval: false,
            createdAt: block.timestamp,
            description: _description
        });
        
        emit EscrowCreated(escrowId, msg.sender, _seller, msg.value);
        emit PaymentDeposited(escrowId, msg.value);
        
        return escrowId;
    }
    
    /**
     * @dev Confirms delivery and releases payment to seller
     * @param _escrowId The ID of the escrow transaction
     */
    function confirmDelivery(uint256 _escrowId) 
        external 
        onlyBuyer(_escrowId) 
        inState(_escrowId, EscrowState.AWAITING_DELIVERY) 
    {
        EscrowTransaction storage escrow = escrows[_escrowId];
        escrow.state = EscrowState.COMPLETE;
        escrow.buyerApproval = true;
        
        uint256 amount = escrow.amount;
        address seller = escrow.seller;
        
        // Transfer payment to seller
        (bool success, ) = payable(seller).call{value: amount}("");
        require(success, "Payment transfer failed");
        
        emit DeliveryConfirmed(_escrowId);
        emit PaymentReleased(_escrowId, seller, amount);
    }
    
    /**
     * @dev Initiates refund process (requires arbiter approval for disputes)
     * @param _escrowId The ID of the escrow transaction
     */
    function requestRefund(uint256 _escrowId) 
        external 
        onlyBuyer(_escrowId) 
        inState(_escrowId, EscrowState.AWAITING_DELIVERY) 
    {
        EscrowTransaction storage escrow = escrows[_escrowId];
        
        // If within 24 hours and seller hasn't objected, allow automatic refund
        if (block.timestamp <= escrow.createdAt + 24 hours) {
            escrow.state = EscrowState.REFUNDED;
            uint256 amount = escrow.amount;
            
            (bool success, ) = payable(escrow.buyer).call{value: amount}("");
            require(success, "Refund transfer failed");
            
            emit RefundIssued(_escrowId, escrow.buyer, amount);
        } else {
            // Require arbiter intervention for disputes after 24 hours
            escrow.buyerApproval = true;
            // State remains AWAITING_DELIVERY until arbiter resolves
        }
    }
    
    /**
     * @dev Resolves dispute (only arbiter can call)
     * @param _escrowId The ID of the escrow transaction
     * @param _refundToBuyer True to refund buyer, false to pay seller
     */
    function resolveDispute(uint256 _escrowId, bool _refundToBuyer) 
        external 
        onlyArbiter(_escrowId) 
        inState(_escrowId, EscrowState.AWAITING_DELIVERY) 
    {
        EscrowTransaction storage escrow = escrows[_escrowId];
        uint256 amount = escrow.amount;
        
        if (_refundToBuyer) {
            escrow.state = EscrowState.REFUNDED;
            (bool success, ) = payable(escrow.buyer).call{value: amount}("");
            require(success, "Refund transfer failed");
            emit RefundIssued(_escrowId, escrow.buyer, amount);
            emit DisputeResolved(_escrowId, escrow.buyer, amount);
        } else {
            escrow.state = EscrowState.COMPLETE;
            (bool success, ) = payable(escrow.seller).call{value: amount}("");
            require(success, "Payment transfer failed");
            emit PaymentReleased(_escrowId, escrow.seller, amount);
            emit DisputeResolved(_escrowId, escrow.seller, amount);
        }
    }
    
    /**
     * @dev Gets escrow details
     * @param _escrowId The ID of the escrow transaction
     * @return EscrowTransaction struct containing all escrow details
     */
    function getEscrow(uint256 _escrowId) external view returns (EscrowTransaction memory) {
        return escrows[_escrowId];
    }
    
    /**
     * @dev Gets the current state of an escrow
     * @param _escrowId The ID of the escrow transaction
     * @return The current state of the escrow
     */
    function getEscrowState(uint256 _escrowId) external view returns (EscrowState) {
        return escrows[_escrowId].state;
    }
    
    /**
     * @dev Gets the total number of escrows created
     * @return The total count of escrows
     */
    function getTotalEscrows() external view returns (uint256) {
        return escrowCounter;
    }
}
