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

contract LiquidateVerifier {
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
    uint256 constant deltax1 = 7349920940120504828209954517095582127167463811626082429776285480611452025322;
    uint256 constant deltax2 = 7052690251891773590049627293377977439926274141953895687955232749851109570323;
    uint256 constant deltay1 = 16939400857224234600263217100855621812293774163161619960845382773929037745851;
    uint256 constant deltay2 = 8065326165641090954096186026360412274580279005918977560799469015697301130631;

    
    uint256 constant IC0x = 15796480947607506497199420157172470489779665688460488714360979545317409142272;
    uint256 constant IC0y = 6250616349886127710345607283830420027817550936915325568379508157403726310955;
    
    uint256 constant IC1x = 4696245449283418812911639983447812628856319483805028250640521400034980772125;
    uint256 constant IC1y = 8384163368876950301122940057826993928994662565509123082612314251008378776928;
    
    uint256 constant IC2x = 3847512081669810096390296849603255114742205134561742423808989076916219497246;
    uint256 constant IC2y = 5667108266859115101353009016953479018543672554678557368582185552401413491241;
    
    uint256 constant IC3x = 19067376341065955842307096718571227684987940857176613358484258740227630443058;
    uint256 constant IC3y = 5231270318428572426745608802058106871039801066774561462324871201569299234560;
    
    uint256 constant IC4x = 5358919766507022732052028857581683781841358429128310248874351248135632718115;
    uint256 constant IC4y = 13530944103832990902490346738118391013683124181998136243712974477020385347743;
    
    uint256 constant IC5x = 9767771631845252680601011341620814187380990094455819410173796857552948430001;
    uint256 constant IC5y = 4907878409117555417589522984250988418548253328606171057036368506229387414460;
    
    uint256 constant IC6x = 2872237972339470394953135370151172394123867103814846799342267444820931239823;
    uint256 constant IC6y = 14825266259075026933165915677551150783703350189859565065087543712435932075248;
    
    uint256 constant IC7x = 3838337077018317738277206827358690527733244860556417880665623287392692476797;
    uint256 constant IC7y = 1864160870870464845274719500011992312190417971281619020808659301918558868442;
    
    uint256 constant IC8x = 11126248222330706298815602442738022371165052397991703133914977971678844205574;
    uint256 constant IC8y = 8852708633311186010691547931776806666914763403792361835499384427268363123812;
    
    uint256 constant IC9x = 18919842345773959552858765617854053589551085067160395479909171803613537156963;
    uint256 constant IC9y = 11870884689317231633385331108491819798808968467093470922255073236658401874806;
    
    uint256 constant IC10x = 12470174619155131485252196776507768814451397108539013590866269807773877076686;
    uint256 constant IC10y = 16468881634694764972127057542133207158891340747949527871016209557605471823790;
    
    uint256 constant IC11x = 16311968616824520004716270124571219160173918974374433775125983271019420570950;
    uint256 constant IC11y = 7715798090390757042129998474864043739457861521650602679848394054467794638823;
    
    uint256 constant IC12x = 9229654822939382192668145121569974234244837996316889559694942402758483791954;
    uint256 constant IC12y = 11385498125661904381344717260921070092221790090880399951056258343480697157593;
    
    uint256 constant IC13x = 6403879146703962888962625687096366605408950994573070508264197798691564378983;
    uint256 constant IC13y = 565920981354614182774452359224125736745157522425501125986050921187492012787;
    
 
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
