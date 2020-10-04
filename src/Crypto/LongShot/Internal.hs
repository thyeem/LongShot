module Crypto.LongShot.Internal where

import           Control.Applicative
import           Control.DeepSeq
import           Control.Parallel               ( par
                                                , pseq
                                                )
import qualified Data.ByteString.Char8         as C
import           Language.Haskell.TH
import           Crypto.LongShot
import           Crypto.LongShot.TH

-- Declaration of bruteforceN: generating code by splicing
$( funcGenerator )

-- | Brute-force search
bruteforce
  :: Int -> String -> String -> (C.ByteString -> C.ByteString) -> Maybe String
bruteforce size chars hex hasher = found
 where
  found  = foldl (<|>) empty (runPar <%> prefixes)
  runPar = bruteforcePar numBind (byteChars chars) (image hex) hasher
  numPrefix | size < defNumPrefix = 1
            | otherwise           = defNumPrefix
  numBind  = size - numPrefix
  prefixes = bytePrefixes numPrefix chars

-- | Pick up a appropriate search function
bruteforcePar
  :: Int
  -> [C.ByteString]
  -> C.ByteString
  -> (C.ByteString -> C.ByteString)
  -> C.ByteString
  -> Maybe String
bruteforcePar n
  | n `elem` [0 .. defNumBind] = $( funcList ) !! n
  | otherwise = errorWithoutStackTrace "Not available search length"

-- | Deep Brute-force search including less than a given search size
bruteforceDeep
  :: Int -> String -> String -> (C.ByteString -> C.ByteString) -> Maybe String
bruteforceDeep size x y z = foldl (<|>) empty found
 where
  found = deep x y z <%> [1 .. size]
  deep a b c d = bruteforce d a b c

-- | Parallel map using deepseq, par and pseq
(<%>) :: (NFData a, NFData b) => (a -> b) -> [a] -> [b]
f <%> []       = []
f <%> (x : xs) = y `par` ys `pseq` (y : ys) where
  y  = force $ f x
  ys = f <%> xs