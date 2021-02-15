module ExitCodes (ExitCode(..), exitWith) where

import qualified System.Exit as Exit

data ExitCode
    = Success
    | ParseError
    | ConnectionError
    | NoTokenError
    deriving (Show, Eq, Enum)

-- | 'System.Exit.exitWith', but with custom 'ExitCode'
exitWith :: ExitCode -> IO a
exitWith Success = Exit.exitSuccess
exitWith exitCode = Exit.exitWith $ Exit.ExitFailure $ fromEnum exitCode
