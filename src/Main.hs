{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main (main) where

import qualified Control.Exception as Exception
import Control.Monad (foldM, forM)
import Control.Monad.Trans.Except (ExceptT(ExceptT), runExceptT)
import qualified Data.Attoparsec.Text as Attoparsec
import qualified Data.ByteString as ByteString
import Data.Either (fromRight)
import Data.HashMap.Strict (HashMap)
import qualified Data.HashMap.Strict as HashMap
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as Text
import qualified Data.Vector as Vector
import ExitCodes (ExitCode(..), exitWith)
-- import qualified Data.ByteString as ByteString
import GitHub (github, Issue(..), IssueComment(..)  {-, NewIssue(..), IssueNumber(..)-})
import qualified GitHub
import Repository (Repository(..), parseRepositoryInformation)
import System.Directory
import System.IO

-- | Like 'withFile', but set encoding to 'utf8' with 'noNewlineTranslation'.
withFileUtf8 :: FilePath -> IOMode -> (Handle -> IO r) -> IO r
withFileUtf8 filePath ioMode f = withFile filePath ioMode $ \handle -> do
    hSetEncoding handle utf8
    hSetNewlineMode handle noNewlineTranslation
    f handle

data LocalIssue =
    LocalIssue { title :: Text, body :: Maybe Text, comments :: HashMap Int LocalComment }
    deriving (Show, Eq)

newtype LocalComment = LocalComment { comment :: Text }
    deriving (Show, Eq)

queryIssues
    :: GitHub.Auth -> Repository -> ExceptT GitHub.Error IO (HashMap GitHub.IssueNumber LocalIssue)
queryIssues aut Repository {owner, repository} = do
    issues <- ExceptT $ github aut $ GitHub.issuesForRepoR owner repository mempty GitHub.FetchAll
    fmap HashMap.fromList
        $ forM (Vector.toList issues)
        $ \Issue {issueNumber, issueTitle, issueBody} -> do
            -- commentsR :: Name Owner -> Name Repo -> IssueNumber -> FetchCount -> Request k (Vector IssueComment)
            comments <- fmap
                (HashMap.fromList
                 . map (\c -> (issueCommentId c, LocalComment { comment = issueCommentBody c }))
                 . Vector.toList)
                $ ExceptT
                $ github aut (GitHub.commentsR owner repository issueNumber GitHub.FetchAll)
            -- TODO
            -- query comments
            -- make Map IssueNumber LocalIssue
            -- clean up directory
            -- include files in directoryNew, sort by new/changed
            -- create new files for current issues
            pure (issueNumber, LocalIssue { title = issueTitle, body = issueBody, comments })

{-
Format:
- Eine Datei "Issues.txt" (macht nur Sinn bei überschaubarer Issue-Anzahl)
- Erst offene Issues bis Trennzeile (_______________________________), danach geschlossene Issues
- Issue-Format:
    #Issue: <Issue-Number>
    <Titel>
    <Leerzeile>
    <Body>
    ~~~~~~~~~~~
    #Comment: <Comment-Number>
    <Comment>
    -------------------------
    #Issue: <Issue-Number>
    ...
-}
main :: IO ()
main = do
    let tokenPath = ".githubtoken"
        tokenMissing = "No Token found in \"" ++ tokenPath ++ "\"."
    aut <- Exception.handle
        (\(_e :: Exception.IOException) -> hPutStrLn stderr tokenMissing >> exitWith NoTokenError)
        $ GitHub.OAuth <$> ByteString.readFile tokenPath
    repositoryInformation@Repository {owner, repository, filePath} <- parseRepositoryInformation
    putStrLn $ "owner: " ++ show owner ++ ", repository: " ++ show repository
    issueFileContents <- Exception.handle (\(_e :: Exception.IOException) -> pure Text.empty)
        $ withFileUtf8 filePath ReadMode Text.hGetContents
    print issueFileContents
    -- issuesForRepoR :: Name Owner -> Name Repo -> IssueRepoMod -> FetchCount -> Request k (Vector Issue)
    remoteIssues <- runExceptT (queryIssues aut repositoryInformation) >>= \case
        Left err -> do
            hPrint stderr err
            exitWith ConnectionError
        Right issues -> pure issues
    -- TODO create new issues
    -- createIssueR :: Name Owner -> Name Repo -> NewIssue -> Request RW Issue
    -- newIssue <- github aut
    --     $ GitHub.createIssueR owner repository
    --     $ NewIssue
    --     { newIssueTitle = "Test"
    --     , newIssueBody = Nothing
    --     , newIssueAssignees = Vector.empty
    --     , newIssueMilestone = Nothing
    --     , newIssueLabels = Nothing
    --     }
    -- TODO edit changed issues
    -- print newIssue
    -- issueR :: Name Owner -> Name Repo -> IssueNumber -> Request k Issue
    -- issue <- github aut $ GitHub.issueR owner repository $ IssueNumber 3
    -- print issue
    -- editIssueR :: Name Owner -> Name Repo -> IssueNumber -> EditIssue -> Request RW Issue
    -- editOfIssue :: EditIssue
    -- createCommentR :: Name Owner -> Name Repo -> IssueNumber -> Text -> Request RW Comment
    -- editCommentR :: Name Owner -> Name Repo -> Id Comment -> Text -> Request RW Comment
    -- curl -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/spamviech/Zugkontrolle/issues
    -- https://docs.github.com/en/rest/reference/issues#list-repository-issues
    -- https://github.com/phadej/github/tree/master/samples/Issues
    -- TODO clean up directoryNew
    exitWith Success
