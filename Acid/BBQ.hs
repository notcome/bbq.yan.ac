{-# LANGUAGE DeriveDataTypeable, TemplateHaskell,
  TypeFamilies, RecordWildCards #-}

module Acid.BBQ where

import Control.Monad.Reader ( ask )
import Control.Monad.State  ( get, put )
import Data.Maybe
import Data.Acid            ( Query, Update, makeAcidic )
import Data.IxSet           ( (@=), Proxy(..), getOne, empty )
import qualified Data.IxSet as IxSet
import Data.BBQ
import Crypto.BCrypt
import Data.ByteString.Char8 ( pack )

initialBBQState :: BBQ
initialBBQState = BBQ
  { nextAccountId = AccountId 1327948
  , accounts      = empty
  }

type MaybeFail t = Either String t

newAccount :: (Email, Password) -> Update BBQ (MaybeFail AccountId)
newAccount (email, password) = do
  bbq@BBQ{..} <- get
  case getOne $ accounts @= email of
    Just _  -> return (Left "该邮箱已被注册")
    Nothing -> do
      let thisAccountId = nextAccountId
      let thisAccount = Account {
          accountId = thisAccountId
        , email     = email
        , password  = password
        , userInfo  = UserInfo "{}"
        }
      put $ bbq
        { nextAccountId = AccountId ((unAccountId thisAccountId) + 13)
        , accounts      = IxSet.insert thisAccount accounts
        }
      return (Right thisAccountId)

resetPassword :: (Email, Password) -> Update BBQ (MaybeFail ())
resetPassword (email, password) = do
  bbq@BBQ{..} <- get
  case getOne $ accounts @= email of
    Nothing         -> return (Left "用户不存在")
    Just oldAccount -> do
      let accountId' = accountId oldAccount
      let newAccount = Account {
          accountId = accountId'
        , email     = email
        , password  = password
        , userInfo  = userInfo oldAccount
        }
      put $ bbq
        { accounts = IxSet.updateIx accountId' newAccount accounts }      
      return $ Right ()

updateUserInfo :: (AccountId, UserInfo) -> Update BBQ (MaybeFail ())
updateUserInfo (accountId', userInfo) = do
  bbq@BBQ{..} <- get
  case getOne $ accounts @= accountId' of
    Nothing         -> return (Left "用户不存在")
    Just oldAccount -> do
      let newAccount = Account {
          accountId = accountId'
        , email     = email oldAccount
        , password  = password oldAccount
        , userInfo  = userInfo
        }
      put $ bbq
        { accounts = IxSet.updateIx accountId' newAccount accounts }      
      return $ Right ()

isEmailRegisterd :: Email -> Query BBQ Bool
isEmailRegisterd email = do
  bbq@BBQ{..} <- ask
  case getOne $ accounts @= email of
    Nothing      -> return False
    Just account -> return True

getAccountId :: Email -> Query BBQ (MaybeFail AccountId)
getAccountId email = do
  bbq@BBQ{..} <- ask
  case getOne $ accounts @= email of
    Nothing      -> return (Left "用户不存在")
    Just account -> return (Right (accountId account))

getUserInfo :: AccountId -> Query BBQ (MaybeFail UserInfo)
getUserInfo accountId = do
  bbq@BBQ{..} <- ask
  case getOne $ accounts @= accountId of
    Nothing      -> return (Left "用户不存在")
    Just account -> return (Right (userInfo account))

authenticate :: (Email, Password) -> Query BBQ (MaybeFail AccountId)
authenticate (email, providedPassword) = do
  bbq@BBQ{..} <- ask
  case getOne $ accounts @= email of
    Nothing      -> return (Left "用户不存在")
    Just account -> do
      let packedPwd = pack (unPassword (password account))
      let packedAttempt = pack (unPassword providedPassword)
      if validatePassword packedPwd packedAttempt
        then return (Right (accountId account))
        else return (Left "密码错误")

listByEmail :: Query BBQ [Account]
listByEmail = do
  BBQ{..} <- ask
  let accounts' = IxSet.toDescList (Proxy :: Proxy Email) accounts
  return accounts'

$(makeAcidic ''BBQ
  [ 'newAccount
  , 'resetPassword
  , 'updateUserInfo
  , 'isEmailRegisterd
  , 'getAccountId
  , 'getUserInfo
  , 'authenticate
  , 'listByEmail
  ])
