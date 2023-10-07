// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/VRFConsumerBase.sol";

contract DegenFlip is VRFConsumerBase {
    
    //vrf variables
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;
    
    mapping(address => uint256) public bets;
    mapping(address => bool) public betChoice;
    mapping(bytes32 => address) public requestIdToAddress; //chainlink id to user address
    
    event randomnessReq(bytes32 requestId);
    event FlipResult(address user, bool userChoice, bool flipResult, uint256 reward);
    
    constructor(address _vrfCoordinator, address _linkToken, bytes32 _keyHash) 
        VRFConsumerBase(_vrfCoordinator, _linkToken) 
    {
        keyHash = _keyHash;
        fee = 0.1 * 10 ** 18; // 0.1
    }
    
    function flipCoin(bool _choice) external payable {
        require(msg.value == 0.01 ether, "Bets have to be 0.01 ETH");
        require(bets[msg.sender] == 0, "You are already in a bet");
        
        bets[msg.sender] = msg.value;
        betChoice[msg.sender] = _choice;
        
        bytes32 requestId = requestRandomness(keyHash, fee);
        requestIdToAddress[requestId] = msg.sender;
        emit randomnessReq(requestId);
    }
    
    //chainlink vrf callback
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        address playerAddress = requestIdToAddress[requestId];
        require(playerAddress != address(0), "Player address is invalid");
        
        //true = heads; false = tails
        bool coinResult = randomness % 2 == 0;
        
        if(coinResult == betChoice[playerAddress]) {
            //payout
            uint256 reward = bets[playerAddress] * 2;
            payable(playerAddress).transfer(reward);
            emit FlipResult(playerAddress, betChoice[playerAddress], coinResult, reward);
        } else {
            emit FlipResult(playerAddress, betChoice[playerAddress], coinResult, 0);
        }
        
        //reset
        delete bets[playerAddress];
        delete betChoice[playerAddress];
        delete requestIdToAddress[requestId];
    }
}
