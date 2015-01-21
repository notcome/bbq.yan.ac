{-# LANGUAGE FlexibleContexts, MultiParamTypeClasses #-}
module Main where

import Control.Exception.Lifted    (bracket)
import Control.Monad.Trans.Control (MonadBaseControl)
import Control.Monad.Trans         (MonadIO(..))

import Data.Acid
import Data.Acid.Local
import Data.Maybe         (fromMaybe)
import Data.Data          (Typeable)
import Happstack.Server
import System.FilePath    ((</>))

import Route
import Data.BBQ
import Data.VCodePool
import Acid.BBQ
import Acid.VCodePool

withLocalState
  :: ( MonadBaseControl IO m
     , MonadIO m
     , IsAcidic st
     , Typeable st
     ) =>
     Maybe FilePath
  -> st
  -> (AcidState st -> m a)
  -> m a
withLocalState mPath initialState =
  bracket (liftIO $ open initialState)
          (liftIO . createCheckpointAndClose)
  where
    open = maybe openLocalState openLocalStateFrom mPath

withAcid 
  :: Maybe FilePath
  -> ((AcidState BBQ, AcidState VCodePool) -> IO a)
  -> IO a
withAcid mBasePath action =
  let basePath = fromMaybe "_state" mBasePath
      bbqPath  = Just $ basePath </> "BBQ"
      poolPath = Just $ basePath </> "Pool"
  in withLocalState bbqPath initialBBQState   $ \b ->
     withLocalState poolPath initialVCodePool $ \p ->
       action (b, p)

main :: IO ()
main =
  withAcid Nothing $ \acid ->
    simpleHTTP nullConf $ dispatch acid
