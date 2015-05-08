{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Distribution.Melpa.Fetcher.Bzr
       ( module Distribution.Melpa.Fetcher.Bzr.Types
       , hash
       ) where

import Control.Applicative
import Control.Error
import qualified Control.Foldl as F
import Control.Monad.IO.Class
import qualified Data.HashMap.Strict as HM
import qualified Data.Text as T
import Prelude hiding (FilePath)
import Turtle

import Distribution.Melpa.Archive (Archive)
import qualified Distribution.Melpa.Archive as A
import Distribution.Melpa.Fetcher
import Distribution.Melpa.Fetcher.Bzr.Types
import Distribution.Melpa.Package (Package(Package))
import qualified Distribution.Melpa.Package as P
import Distribution.Melpa.Recipe
import Distribution.Melpa.Utils (indir)

hash :: FilePath -> FilePath -> Bool -> Text -> Archive -> Recipe -> EitherT Text IO Package
hash _ _ True name _ _ = left (name <> ": stable fetcher 'bzr' not implemented")
hash melpa _ stable name arch rcp = do
  let Bzr _bzr@(Fetcher {..}) = fetcher rcp
  _commit <- getCommit melpa stable name _bzr
  _hash <- prefetch name _bzr _commit
  return Package
    { P.ver = A.ver arch
    , P.deps = maybe [] HM.keys (A.deps arch)
    , P.recipe = rcp { fetcher = Bzr (_bzr { commit = Just _commit }) }
    , P.hash = _hash
    }

getCommit :: FilePath -> Bool -> Text -> Bzr -> EitherT Text IO Text
getCommit melpa stable name Fetcher {..} =
  if stable
    then left (name <> ": stable fetcher 'bzr' not implemented")
  else do
    let revno = "revno:" *> spaces *> plus digit
    mcommit <- liftIO
               $ indir (melpa </> "working" </> fromString (T.unpack name))
               $ fold (grep revno (inproc "bzr" ["log"] empty)) F.head
    case mcommit of
      Nothing -> left (name <> ": could not get bzr revno")
      Just c -> return c

prefetch :: Text -> Bzr -> Text -> EitherT Text IO Text
prefetch name bzr commit = do
  mhash <- liftIO $ do
    export "QUIET" "1"
    mhash <- fold (inproc "nix-prefetch-bzr" [url bzr, commit] empty) F.last
    unset "QUIET"
    return mhash
  case mhash of
    Nothing -> left (name <> ": could not prefetch bzr")
    Just h -> return h
