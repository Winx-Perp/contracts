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

contract IncreaseVerifier {
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
    uint256 constant deltax1 = 3081813473250592299586752475822417514998862435697805895248693017946578161624;
    uint256 constant deltax2 = 13578333048784676336339007795906959478518399723574188970143233079467135021114;
    uint256 constant deltay1 = 15446757016719729760418030179803750771624456360165596191377378218108406166887;
    uint256 constant deltay2 = 5223141896400956336674673519394600642363471089261504144485022514598679791449;

    
    uint256 constant IC0x = 16553806370697149779968858807050684861991229781984651051261204504861841077511;
    uint256 constant IC0y = 7479777374775944563655045051256222666272639937301856756393747479209674926736;
    
    uint256 constant IC1x = 7773179093043159304269810720165341897316998138239513987762159899308808944772;
    uint256 constant IC1y = 9853249128231353370645599335975938564128395107536164240296064244588806262999;
    
    uint256 constant IC2x = 10473656900672844371092737115685765126585436563892882120394605147065728111410;
    uint256 constant IC2y = 15405615014744070571311287452845694273871368249675938317531286303405580734205;
    
    uint256 constant IC3x = 20119627992088584901518183533934060743287010970679764190082742440456685224688;
    uint256 constant IC3y = 20102480487998264475185989971307896572891329472085508277692200003673294772881;
    
    uint256 constant IC4x = 10725745270721663566034402951633619571518143507204576412469986607226755668635;
    uint256 constant IC4y = 21761622547193088933583427689427129300793938490840665741300348467260976072250;
    
    uint256 constant IC5x = 878062584166268693298037586971752186329503457769810826049897567594114858805;
    uint256 constant IC5y = 1983058041358478940561465896792708442996408667568220924783852300650193752751;
    
    uint256 constant IC6x = 3369489585719681001844252231122979089721307585930592163917155399196590127971;
    uint256 constant IC6y = 20347638148539381636837504817956846345049338312906847765145606942597986844728;
    
    uint256 constant IC7x = 13839139927266990729397811709977710870296840877142688000540254358753823035779;
    uint256 constant IC7y = 6176714005366879362440774303714250984229580307939274136640711666386076284452;
    
    uint256 constant IC8x = 12314472900441810422975161750930229114746535099146258050863757130513922038459;
    uint256 constant IC8y = 8363482201878741218265961408436833921448503835131953561688718144418332293652;
    
    uint256 constant IC9x = 10920427366884351170824067032636697789913505820830031873429972166616453593436;
    uint256 constant IC9y = 8581759324216575829815249446327833400600943546866853897731689119558632542727;
    
    uint256 constant IC10x = 12725990615652817205072773405533644966093680587008035386671015925761815118014;
    uint256 constant IC10y = 12685515621520438256494616743284512810141006063884897930139394656332994135307;
    
    uint256 constant IC11x = 1497315770753455400578053876769027127423692542348313431656964785404159631039;
    uint256 constant IC11y = 10354198521781321027955343032177364398152381291889317812760752142752399631652;
    
    uint256 constant IC12x = 13490580881059518652580711625936157791785871037106638528390072680368875436495;
    uint256 constant IC12y = 2637210208042201431589633413817462628455496944508282372815495936057488320114;
    
    uint256 constant IC13x = 341333958055010998918282069672499520902403863521903695040466043759466658666;
    uint256 constant IC13y = 2473673304512320672907979391939716068886250838552479771051693394176078553991;
    
    uint256 constant IC14x = 19925842804008773018190569018611735085274920230955574703458420892556792207113;
    uint256 constant IC14y = 8936919594205826207981902117147921852439692421822552366503501171381046551717;
    
 
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
