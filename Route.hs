module Route where

import Control.Monad
import Data.Acid        (AcidState)
import Happstack.Server

import Data.BBQ
import Data.VCodePool
import Data.RequestState

import CheckUserAuth
import Layout.Basic

import Page.StaticPages

dispatch :: (AcidState BBQ, AcidState VCodePool) -> ServerPartT IO Response
dispatch (bbq, vcodePool) = do
  authResult        <- checkUserAuth vcodePool
  let basicTemplate' = basicTemplate authResult
  let state          = mkRequestState bbq vcodePool authResult basicTemplate'
  route $ runHandler state  


route :: (Handler Response -> ServerPartT IO Response) -> ServerPartT IO Response
route runHandler = msum [
    dir "public" $ serveDirectory DisableBrowsing [] "public"
  , runHandler staticPages
  ]
