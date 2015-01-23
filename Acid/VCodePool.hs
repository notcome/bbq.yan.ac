{-# LANGUAGE DeriveDataTypeable, TemplateHaskell, 
  TypeFamilies, FlexibleContexts, NamedFieldPuns #-}

module Acid.VCodePool where

import Control.Monad.Reader ( ask )
import Control.Monad.State  ( get, put )
import Control.Monad.Trans
import Data.Data            ( Data, Typeable )
import Data.Maybe
import Data.Acid            ( Query, Update, makeAcidic )
import Data.IxSet           ( (@=), Proxy(..), getOne, empty )
import qualified Data.IxSet as IxSet
import Data.BBQ
import Data.VCodePool

initialVCodePools :: VCodePools
initialVCodePools = VCodePools empty empty empty

updateNewAccountPool  pools pool = pools { newAccountPool  = pool }
updateResetPasswdPool pools pool = pools { resetPasswdPool = pool }
updateCookiePool      pools pool = pools { cookiePool      = pool }

newVCodeRecord
  :: (IxSet.Indexable (VCodeRecord k), Typeable k, Ord k)
  => (VCodePools -> VCodePool k)
  -> (VCodePools -> VCodePool k -> VCodePools)
  -> k -> VCode -> ExpireTime -> Update VCodePools ()
newVCodeRecord extract update key vcode expireTime = do
  let record = VCodeRecord key vcode expireTime
  pools <- get
  let pool = extract pools
  let pool' = IxSet.updateIx key record pool
  put $ update pools pool'

insertNewAccount   :: Email -> VCode -> ExpireTime -> Update VCodePools ()
insertNewAccount k  = newVCodeRecord newAccountPool updateNewAccountPool k
insertResetPasswd  :: Email -> VCode -> ExpireTime -> Update VCodePools ()
insertResetPasswd k = newVCodeRecord resetPasswdPool updateResetPasswdPool k
insertCookie       :: AccountId -> VCode -> ExpireTime -> Update VCodePools ()
insertCookie k      = newVCodeRecord cookiePool updateCookiePool k

verifyVCodeRecord
  :: (IxSet.Indexable (VCodeRecord k), Typeable k, Ord k)
  => (VCodePools -> VCodePool k)
  -> k -> VCode -> ExpireTime -> Query VCodePools (Either String ())
verifyVCodeRecord extract key givenCode now = do
  pools <- ask
  let pool = extract pools
  case getOne $ pool @= key of
    Nothing -> return $ (Left "验证记录不存在")
    Just VCodeRecord { vcode, expireTime } ->
      if vcode /= givenCode
        then return $ (Left "无效的验证信息")
        else if expireTime < now
          then return $ (Left "验证信息已过期")
          else return $ (Right ())

verifyNewAccount   :: Email -> VCode -> ExpireTime -> Query VCodePools (Either String ())
verifyNewAccount k  = verifyVCodeRecord newAccountPool k
verifyResetPasswd  :: Email -> VCode -> ExpireTime -> Query VCodePools (Either String ())
verifyResetPasswd k = verifyVCodeRecord resetPasswdPool k
verifyCookie       :: AccountId -> VCode -> ExpireTime -> Query VCodePools (Either String ())
verifyCookie k      = verifyVCodeRecord cookiePool k

deleteVCodeRecord
  :: (IxSet.Indexable (VCodeRecord k), Typeable k, Ord k)
  => (VCodePools -> VCodePool k)
  -> (VCodePools -> VCodePool k -> VCodePools)
  -> k -> Update VCodePools ()
deleteVCodeRecord extract update key = do
  pools <- get
  let pool = extract pools
  let pool' = IxSet.deleteIx key pool
  put $ update pools pool'

deleteNewAccountRecord  :: Email -> Update VCodePools ()
deleteNewAccountRecord  = deleteVCodeRecord newAccountPool updateNewAccountPool
deleteResetPasswdRecord :: Email -> Update VCodePools ()
deleteResetPasswdRecord = deleteVCodeRecord resetPasswdPool updateResetPasswdPool

getPools :: Query VCodePools VCodePools
getPools = ask

$(makeAcidic ''VCodePools
  [ 'insertNewAccount
  , 'insertResetPasswd
  , 'insertCookie
  , 'verifyNewAccount
  , 'verifyResetPasswd
  , 'verifyCookie
  , 'deleteNewAccountRecord
  , 'deleteResetPasswdRecord
  , 'getPools
  ])
