module Pinafore.Library.Joplin (joplinPackages) where

import Pinafore.API
import Shapes
import Data.ByteString.Lazy qualified as BL
import Codec.Archive.Tar qualified as Tar
import Pinafore.Library.Media ()


extractTarEntries :: MonadFail m => Tar.Entries Tar.FormatError -> m [(Text, LazyByteString)]
extractTarEntries = \case
    Tar.Fail err -> fail $ show err
    Tar.Done -> return []
    Tar.Next e ee ->
        case Tar.entryContent e of
            Tar.NormalFile c _ -> do
                cc <- extractTarEntries ee
                return $ (pack $ Tar.entryPath e, c) : cc
            Tar.Directory -> extractTarEntries ee
            ec -> fail $ "unexpected tar entry: " <> show ec

extractTar :: MonadFail m => LazyByteString -> m [(Text, LazyByteString)]
extractTar lbs = extractTarEntries $ Tar.read lbs

extractTarFile :: Text -> IO [(Text, LazyByteString)]
extractTarFile filePath = do
    lbs <- BL.readFile $ unpack filePath
    extractTar lbs



splitJoplinNote :: [Text] -> Maybe ([Text],[Text])
splitJoplinNote [] = Nothing
splitJoplinNote ("":tt) | Nothing <- splitJoplinNote tt = return ([],tt)
splitJoplinNote (t:tt) = do
    (a,b) <- splitJoplinNote tt
    return (t:a,b)

type Note = ([(Text, Text)],Maybe Text)

type M = StateT String Maybe

runM :: M a -> String -> Maybe a
runM (StateT st) s = do
    (r, _) <- st s
    return r

readMatch :: (Char -> Bool) -> M Char
readMatch tst = StateT $ \case
    (c:cc) | tst c -> Just (c, cc)
    _ -> Nothing

readThisChar :: Char -> M ()
readThisChar c = void $ readMatch (== c)

readThisString :: String -> M ()
readThisString s = for_ s readThisChar

readChar :: M Char
readChar = StateT $ \case
    (c:cc)  -> Just (c, cc)
    [] -> Nothing

readEnd :: M ()
readEnd = StateT $ \case
    (_:_)  -> Nothing
    [] -> Just ((), [])

readRest :: M String
readRest = StateT $ \s -> Just (s, [])

readID :: M StrictByteString
readID = do
    s <- for (zltList 32) $ \_ -> readChar
    lift $ fromStrictHexadecimal s

readResourceName :: M (StrictByteString, Either () String)
readResourceName = do
    readThisString "resources/"
    rid <- readID
    readThisChar '.'
    ext <- readRest
    return (rid,Right ext)

readNoteName :: M (StrictByteString, Either () String)
readNoteName = do
    rid <- readID
    readThisString ".md"
    readEnd
    return (rid, Left ())

readName :: Text -> Maybe (StrictByteString, Either () String)
readName name = runM (readResourceName <|> readNoteName) (unpack name)

readHeader :: M (Text, Text)
readHeader = do
    n <- many $ readMatch (/= ':')
    readThisString ": "
    v <- readRest
    return (pack n, pack v)

importJoplinNote :: MonadFail m => Text -> m Note
importJoplinNote src = do
    let
        l = lines src
        (headerLines, body) = case splitJoplinNote l of
            Nothing -> (l, Nothing)
            Just (b,h) -> (h,Just $ intercalate "\n" b)
    headers <- for headerLines $ \h -> case runM readHeader $ unpack h of
        Nothing -> fail $ "bad header: " <> show h
        Just nv -> return nv
    return (headers, body)

type MapL a b = [(a,b)]

getNote :: LazyByteString -> IO Note
getNote content = case decode utf8Codec $ toStrict content of
    FailureResult err -> fail $ show err
    SuccessResult text -> importJoplinNote text

extensionToMediaType :: String -> Maybe MediaType
extensionToMediaType = \case
    "png" -> Just $ MkMediaType ImageMediaType "png" []
    "pdf" -> Just $ MkMediaType ApplicationMediaType "pdf" []
    _ -> Nothing

getMedia :: String -> LazyByteString -> IO Media
getMedia ext content = case extensionToMediaType ext of
    Just mtype -> return $ MkMedia mtype $ toStrict content
    Nothing -> fail $ "unrecognised file extension: " <> show ext

itemToENM :: Either () String -> LazyByteString -> IO (Either Note Media)
itemToENM (Left ()) content = fmap Left $ getNote content
itemToENM (Right ext) content = fmap Right $ getMedia ext content

importJoplin :: Text -> IO (MapL StrictByteString (Either Note Media))
importJoplin filePath = do
    entries <- extractTarFile filePath
    for entries $ \(eName, content) ->
        case readName eName of
            Nothing -> fail $ "bad name: " <> show eName
            Just (rid, item) -> do
                enm <- itemToENM item content
                return (rid, enm)

libraryStuff :: LibraryStuff
libraryStuff =
    headingBDS "Joplin" "" $
    pure $
    namespaceBDS "Joplin"
        [
            valBDS "readFile" "" importJoplin
        ]

joplinPackages :: Packages
joplinPackages = libraryModulePackages
        $ MkLibraryModule "joplin"
        $ libraryStuff
