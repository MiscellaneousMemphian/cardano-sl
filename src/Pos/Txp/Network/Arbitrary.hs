{-# LANGUAGE TemplateHaskell #-}

-- | 'Arbitrary' instances for 'Pos.Txp.Network' types defined in 'src'

module Pos.Txp.Network.Arbitrary () where

import           Universum

import           Data.DeriveTH                 (derive, makeArbitrary)
import           Test.QuickCheck               (Arbitrary (..))

import           Pos.Binary.Update             ()
import           Pos.Communication.Types.Relay (DataMsg (..))
import           Pos.Core.Arbitrary            ()
import           Pos.Txp.Arbitrary             ()
import           Pos.Txp.Network.Types         (TxMsgContents (..))

derive makeArbitrary ''TxMsgContents

instance Arbitrary (DataMsg TxMsgContents) where
    arbitrary = DataMsg <$> arbitrary
