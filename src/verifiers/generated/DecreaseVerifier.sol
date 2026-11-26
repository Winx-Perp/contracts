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

contract DecreaseVerifier {
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
    uint256 constant deltax1 = 10451979536744747238856450751595929537767658748091932038323788027744529691700;
    uint256 constant deltax2 = 18955004879990326105551590602667032881720438789428738810859954171365101798699;
    uint256 constant deltay1 = 14667608512954253900094523994097884696459698919045346199009630935912514336652;
    uint256 constant deltay2 = 18398932763458889868556145878888562891390300936544888500112519270437892607035;

    
    uint256 constant IC0x = 1056837793751981139607539926583946393066379091185915449716728702545330511923;
    uint256 constant IC0y = 3985932396189777182454846719109139300633434836737510579340969200722634002652;
    
    uint256 constant IC1x = 3395634372172000608218603195306468016188545027784546531588514661173945800854;
    uint256 constant IC1y = 15584467917068327003810693932852337545073777649644520253178437766638793237977;
    
    uint256 constant IC2x = 12221013810686242749747462659060852685286867474943476948963240891176308246820;
    uint256 constant IC2y = 7718574405166832037462858098434846592496986635363467816829448822199322327848;
    
    uint256 constant IC3x = 17083740412132752422333792328155903717293340733172237709811057894075863225802;
    uint256 constant IC3y = 2571124970853891608305251043692892074569936839399679892172554282171857300780;
    
    uint256 constant IC4x = 11210550678830663325685705836561825546100662112022958600379971188248638472045;
    uint256 constant IC4y = 3118172807722127063510920365597743751875577596486497595858811850310656691349;
    
    uint256 constant IC5x = 16387038187926258596468302438314485951937723127561459812221267991372070095242;
    uint256 constant IC5y = 7623522973188248332765559763904738869397740322966151847846051051612159278602;
    
    uint256 constant IC6x = 13185529277516557309970675187237981697847810491595289907801507328476617000446;
    uint256 constant IC6y = 15288429464206792858632446404205161840363343236729842953833556392755480224782;
    
    uint256 constant IC7x = 9376130711787500765090682551508220896228786199281197719163473008754100069880;
    uint256 constant IC7y = 6501157712287993390847467669526868570649491953654049766268505042461957070045;
    
    uint256 constant IC8x = 5007090399347626679493896005973742259180942400017424815421982038129217043169;
    uint256 constant IC8y = 11952380729161046636551030782263175450601560295066633492823355646538974363647;
    
    uint256 constant IC9x = 16351405205743141048909637999281382454164186026518717701492790675047276014732;
    uint256 constant IC9y = 20055384318028204364198515408983565265512032161521268542760363793152632208678;
    
    uint256 constant IC10x = 7655864062994288267923139488584264595900842615033514600444314509768022945051;
    uint256 constant IC10y = 18539968480304335372835400419583535011621123299070012724074402845362075066314;
    
    uint256 constant IC11x = 14166496041155454795417378164175320944720541591045155777691410971965499947444;
    uint256 constant IC11y = 13606060128286036097667770705216722534178834187887029091472359658858254592038;
    
    uint256 constant IC12x = 6276946677610264882948909969269420507849941938530528949017620213186820768077;
    uint256 constant IC12y = 6088355050655673621417864839042559919406965516147159400091592471404310366504;
    
    uint256 constant IC13x = 1220884545196319230876984528841613484621256395584182024872003376900699405951;
    uint256 constant IC13y = 9496272980313581119775583944351414528969302319388784624040086055582517501395;
    
    uint256 constant IC14x = 6534642921386416706272855643468281675136017800578739685587923352136093524307;
    uint256 constant IC14y = 3645710568981423896808969327235115666295862729954322960688145259411753649152;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[14] calldata _pubSignals) public view returns (bool) {
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
                
                g1_mulAccC(_pVk, IC14x, IC14y, calldataload(add(pubSignals, 416)))
                

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
            
            checkField(calldataload(add(_pubSignals, 416)))
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
