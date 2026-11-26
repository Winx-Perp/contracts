// SPDX-License-Identifier: GPL-3.0
/*
    Copyright 2021 0KIMS association.

    This file is generated with [snarkJS](https://github.com/iden3/snarkjs).

    snarkJS is a free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    snarkJS is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
    License for more details.

    You should have received a copy of the GNU General Public License
    along with snarkJS. If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity >=0.7.0 <0.9.0;

contract CloseVerifier {
    // Scalar field size
    uint256 constant r    = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size
    uint256 constant q   = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification Key data
    uint256 constant alphax  = 17188688492121384069712715287412148991066377411077612933173569075768693096393;
    uint256 constant alphay  = 8684332254110838102282941630088396537979932700650067222365611818110910767247;
    uint256 constant betax1  = 1640072608591208456963340802099754047796388165692822100614001515415775882221;
    uint256 constant betax2  = 19785628227438737568699305101134773425380777238703525164151424739304729954790;
    uint256 constant betay1  = 9940272291073976750107706817960537664884052821218789615837045987873492543178;
    uint256 constant betay2  = 5055257376678004056517745999534302893767737483852549471688436913847863004770;
    uint256 constant gammax1 = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 = 919545506809079992200327140333018179472550330651791575316415637917021613042;
    uint256 constant deltax2 = 19196834462147466608854410755048001008466220402249675903717402059143425073739;
    uint256 constant deltay1 = 6137728463761924106150823562843748899289052408973810622661722666373916775487;
    uint256 constant deltay2 = 20525813965882704642541788736605641450238605559541866637155979063753483117562;

    
    uint256 constant IC0x = 20784320029289254161763032297015530836303048205894853943759033968406995434395;
    uint256 constant IC0y = 2965254388774657541541738750270044193823040358847840388486769742123028279079;
    
    uint256 constant IC1x = 6538298556933057394698260217791864036964911272053105275643799989767554748848;
    uint256 constant IC1y = 63851134009691141390800552222194713467897954493936176746393461918305334437;
    
    uint256 constant IC2x = 10708878615815398763018109492204850079779490510819041644184187951162839645193;
    uint256 constant IC2y = 5434200980694582489390323319187004161236544523511464851313400927130457610910;
    
    uint256 constant IC3x = 21854485597753526420158506345643720261480694595758443901626191283993288523028;
    uint256 constant IC3y = 3525998264891709718761489493274808744108967797780170960141693771390665898349;
    
    uint256 constant IC4x = 18446892557582107200672853644499439108832373975971944177101017741037464582449;
    uint256 constant IC4y = 5647897864669673826073608212717116551100742002071008592523946477768679137921;
    
    uint256 constant IC5x = 9591475684257363556041086099074958839313221916300032716828852905791738285322;
    uint256 constant IC5y = 3321449007312157400625205495169662166062373910834634010875299584922426758357;
    
    uint256 constant IC6x = 20730812830226292306068293559915467141390309570241343555760350443108735246213;
    uint256 constant IC6y = 17684555497934035190800323702372990824168063643075579942325635435787356600492;
    
    uint256 constant IC7x = 17786861531808247989066527761687829158086212445576999581279169710730968625906;
    uint256 constant IC7y = 595172326465951006867154541900888725716822767975266334428051579158406231477;
    
    uint256 constant IC8x = 3116234793776620189505567652128488985261047742409480211047238115151966745975;
    uint256 constant IC8y = 11991864752788430645568997747729767454969016754466397420329846397507305809186;
    
    uint256 constant IC9x = 14790132374314445811436337788660691207538149497255288043163565593403829105300;
    uint256 constant IC9y = 15913301058802339183882448207822563354857006018991658493955763088960190620031;
    
    uint256 constant IC10x = 16614231429457564194448995155188802214395757907120729689337800342874064797287;
    uint256 constant IC10y = 16364293802484110639710928856062805301677690088614320812539017286341434230044;
    
    uint256 constant IC11x = 11459839901707085830669864870973107938264919989649826072159665782254069166388;
    uint256 constant IC11y = 16919524452520571793196348842725803069490891189974519324507319662325836608025;
    
    uint256 constant IC12x = 20717792843423599344460020565677927274675265332465036606762121522491547053628;
    uint256 constant IC12y = 18254295296976267799313961965401833099561263789840261859450659024503095622646;
    
    uint256 constant IC13x = 15660486623378794726916488615651307105350190554076568596084134961044008711662;
    uint256 constant IC13y = 19441420111189156815285337789930704832479143295165694993417744674480977274404;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[13] calldata _pubSignals) public view returns (bool) {
        assembly {
            function checkField(v) {
                if iszero(lt(v, r)) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }
            
            // G1 function to multiply a G1 value(x,y) to value in an address
            function g1_mulAccC(pR, x, y, s) {
                let success
                let mIn := mload(0x40)
                mstore(mIn, x)
                mstore(add(mIn, 32), y)
                mstore(add(mIn, 64), s)

                success := staticcall(sub(gas(), 2000), 7, mIn, 96, mIn, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }

                mstore(add(mIn, 64), mload(pR))
                mstore(add(mIn, 96), mload(add(pR, 32)))

                success := staticcall(sub(gas(), 2000), 6, mIn, 128, pR, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }

            function checkPairing(pA, pB, pC, pubSignals, pMem) -> isOk {
                let _pPairing := add(pMem, pPairing)
                let _pVk := add(pMem, pVk)

                mstore(_pVk, IC0x)
                mstore(add(_pVk, 32), IC0y)

                // Compute the linear combination vk_x
                
                g1_mulAccC(_pVk, IC1x, IC1y, calldataload(add(pubSignals, 0)))
                
                g1_mulAccC(_pVk, IC2x, IC2y, calldataload(add(pubSignals, 32)))
                
                g1_mulAccC(_pVk, IC3x, IC3y, calldataload(add(pubSignals, 64)))
                
                g1_mulAccC(_pVk, IC4x, IC4y, calldataload(add(pubSignals, 96)))
                
                g1_mulAccC(_pVk, IC5x, IC5y, calldataload(add(pubSignals, 128)))
                
                g1_mulAccC(_pVk, IC6x, IC6y, calldataload(add(pubSignals, 160)))
                
                g1_mulAccC(_pVk, IC7x, IC7y, calldataload(add(pubSignals, 192)))
                
                g1_mulAccC(_pVk, IC8x, IC8y, calldataload(add(pubSignals, 224)))
                
                g1_mulAccC(_pVk, IC9x, IC9y, calldataload(add(pubSignals, 256)))
                
                g1_mulAccC(_pVk, IC10x, IC10y, calldataload(add(pubSignals, 288)))
                
                g1_mulAccC(_pVk, IC11x, IC11y, calldataload(add(pubSignals, 320)))
                
                g1_mulAccC(_pVk, IC12x, IC12y, calldataload(add(pubSignals, 352)))
                
                g1_mulAccC(_pVk, IC13x, IC13y, calldataload(add(pubSignals, 384)))
                

                // -A
                mstore(_pPairing, calldataload(pA))
                mstore(add(_pPairing, 32), mod(sub(q, calldataload(add(pA, 32))), q))

                // B
                mstore(add(_pPairing, 64), calldataload(pB))
                mstore(add(_pPairing, 96), calldataload(add(pB, 32)))
                mstore(add(_pPairing, 128), calldataload(add(pB, 64)))
                mstore(add(_pPairing, 160), calldataload(add(pB, 96)))

                // alpha1
                mstore(add(_pPairing, 192), alphax)
                mstore(add(_pPairing, 224), alphay)

                // beta2
                mstore(add(_pPairing, 256), betax1)
                mstore(add(_pPairing, 288), betax2)
                mstore(add(_pPairing, 320), betay1)
                mstore(add(_pPairing, 352), betay2)

                // vk_x
                mstore(add(_pPairing, 384), mload(add(pMem, pVk)))
                mstore(add(_pPairing, 416), mload(add(pMem, add(pVk, 32))))


                // gamma2
                mstore(add(_pPairing, 448), gammax1)
                mstore(add(_pPairing, 480), gammax2)
                mstore(add(_pPairing, 512), gammay1)
                mstore(add(_pPairing, 544), gammay2)

                // C
                mstore(add(_pPairing, 576), calldataload(pC))
                mstore(add(_pPairing, 608), calldataload(add(pC, 32)))

                // delta2
                mstore(add(_pPairing, 640), deltax1)
                mstore(add(_pPairing, 672), deltax2)
                mstore(add(_pPairing, 704), deltay1)
                mstore(add(_pPairing, 736), deltay2)


                let success := staticcall(sub(gas(), 2000), 8, _pPairing, 768, _pPairing, 0x20)

                isOk := and(success, mload(_pPairing))
            }

            let pMem := mload(0x40)
            mstore(0x40, add(pMem, pLastMem))

            // Validate that all evaluations ∈ F
            
            checkField(calldataload(add(_pubSignals, 0)))
            
            checkField(calldataload(add(_pubSignals, 32)))
            
            checkField(calldataload(add(_pubSignals, 64)))
            
            checkField(calldataload(add(_pubSignals, 96)))
            
            checkField(calldataload(add(_pubSignals, 128)))
            
            checkField(calldataload(add(_pubSignals, 160)))
            
            checkField(calldataload(add(_pubSignals, 192)))
            
            checkField(calldataload(add(_pubSignals, 224)))
            
            checkField(calldataload(add(_pubSignals, 256)))
            
            checkField(calldataload(add(_pubSignals, 288)))
            
            checkField(calldataload(add(_pubSignals, 320)))
            
            checkField(calldataload(add(_pubSignals, 352)))
            
            checkField(calldataload(add(_pubSignals, 384)))
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
