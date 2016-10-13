{-# LANGUAGE ScopedTypeVariables #-}

-- | Transaction related functions.

module Pos.Types.Tx
       ( verifyTxAlone
       , verifyTx
       ) where

import           Control.Lens    (view, _3)
import           Formatting      (build, int, sformat, (%))
import           Serokell.Util   (VerificationRes, verifyGeneric)
import           Universum

import           Pos.Crypto      (verify)
import           Pos.Types.Types (Address (..), Coin (..), Tx (..), TxIn (..), TxOut (..),
                                  coinF)

-- | Verify that Tx itself is correct. Most likely you will also want
-- to verify that inputs are legal, signed properly and have enough coins.
verifyTxAlone :: Tx -> VerificationRes
verifyTxAlone Tx {..} =
    mconcat
        [ verifyGeneric
              [ (not (null txInputs), "transaction doesn't have inputs")
              , (not (null txOutputs), "transaction doesn't have outputs")
              ]
        , verifyOutputs
        ]
  where
    verifyOutputs = verifyGeneric $ map outputPredicate $ zip [0 ..] txOutputs
    outputPredicate (i :: Word, TxOut {..}) =
        ( txOutValue > 0
        , sformat
              ("output #" %int% " has non-positive value: "%coinF) i txOutValue)

-- | Verify Tx correctness using magic function which resolves input
-- into Address and Coin. It does checks from verifyTxAlone and the
-- following:
--
-- ★ sum of inputs ≥ sum of outputs;
-- ★ every input is signed properly;
-- ★ every input is a known unspent output.
verifyTx :: (TxIn -> Maybe (Address, Coin)) -> Tx -> VerificationRes
verifyTx inputResolver tx@Tx {..} =
    mconcat [verifyTxAlone tx, verifySum, verifyInputs]
  where
    outSum :: Coin
    outSum = sum $ map txOutValue txOutputs
    extendedInputs :: [Maybe (TxIn, Address, Coin)]
    extendedInputs = fmap extendInput txInputs
    extendInput txIn = (\(a, c) -> (txIn, a, c)) <$> inputResolver txIn
    inpSum :: Coin
    inpSum = sum $ map (view _3) $ catMaybes extendedInputs
    verifySum =
        verifyGeneric
            [ ( inpSum >= outSum
              , sformat
                    ("sum of outputs is more than sum of inputs ("
                     %coinF%" > "%coinF%"), maybe some inputs are invalid")
                    outSum inpSum)
            ]
    verifyInputs =
        verifyGeneric $ foldMap inputPredicates $ zip [0 ..] extendedInputs
    inputPredicates (i, Nothing) =
        [(False, sformat ("input #" %int % " is not an unspent output: ") i)]
    inputPredicates (i :: Word, Just (txIn@TxIn {..}, Address pk, _)) =
        [ ( verify pk (txInHash, txInIndex, txOutputs) txInSig
          , sformat
                ("input #"%int%" is not signed properly: ("%build%")") i txIn
          )
        ]
