// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import {TypedMemView} from "./libs/TypedMemView.sol";
import {ViewBTC} from "./libs/ViewBTC.sol";
import {ViewSPV} from "./libs/ViewSPV.sol";

contract Bitsync is Ownable2Step {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using ViewBTC for bytes29;
    using ViewSPV for bytes29;

    uint256 public minWorkPerSync;
    uint256 public minBlockPerSync;
    // block hash => block merkleRoot
    mapping (bytes32 => bytes32) public merkleRoots;
    bytes32 public lastSyncedBlockHash;

    event Syncing(bytes32 indexed blockHash,bytes32 indexed merkleRoot);
    event SetParam(uint256 indexed _minWorkPerSync,uint256 indexed _minBlockPerSync);
  
    constructor(address _owner){
       _transferOwnership(_owner);
    }

    function setParam(uint256 _minWorkPerSync,uint256 _minBlockPerSync) external onlyOwner{
        require(_minBlockPerSync != 0 && _minWorkPerSync != 0,"value_0");
        minWorkPerSync = _minWorkPerSync;
        minBlockPerSync = _minBlockPerSync;
        emit SetParam(_minWorkPerSync,_minBlockPerSync);
    }


    function syncing(bytes memory _headers)external {
       bytes29 arr = _headers.ref(0).tryAsHeaderArray().assertValid();
       uint256 num = arr.len() / 80;
       require(num == minBlockPerSync,"proof block not enough");
       uint256 totalWork = arr.checkChain();
       require(totalWork >= minWorkPerSync,"work not enough");
       bytes29 firstBlock = arr.indexHeaderArray(0);
       require(firstBlock.checkParent(lastSyncedBlockHash),"sync incontinuity");
       lastSyncedBlockHash = firstBlock.workHash();
       bytes32 merkleRoot = firstBlock.merkleRoot();
       merkleRoots[lastSyncedBlockHash] = merkleRoot;
       emit Syncing(lastSyncedBlockHash,merkleRoot);
    }


    function verify(bytes32 _txid,bytes32 _blockHash,bytes memory _proof,uint256 _index)external view returns(bool){
        bytes32 merkleRoot = merkleRoots[_blockHash];
        require(merkleRoot != bytes32(''),"wait syncing");
        bytes29 _proof_ref = _proof.ref(0).tryAsMerkleArray();
        return ViewSPV.prove(_txid, merkleRoot, _proof_ref, _index);
    }

}