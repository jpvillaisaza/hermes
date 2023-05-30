{-# LANGUAGE DeriveGeneric #-}

module Hades where

-- aeson
import Data.Aeson (FromJSON(..), ToJSON(..))
import qualified Data.Aeson as Aeson

-- base
import Data.List (find)
import Data.Maybe (catMaybes, fromMaybe)
import Data.Traversable (for)
import GHC.Generics (Generic)
import System.Environment (getArgs)

-- bytestring
import qualified Data.ByteString.Lazy.Char8 as ByteString.Lazy

-- http-client
import Network.HTTP.Client (Manager)
import qualified Network.HTTP.Client as HttpClient

-- http-client-tls
import qualified Network.HTTP.Client.TLS as HttpClientTls

-- network-uri
import Network.URI (URI)
import qualified Network.URI as Uri

-- tagsoup
import qualified Text.HTML.TagSoup as TagSoup
import Text.StringLike (StringLike)

-- text
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Lazy as TextLazy
import qualified Data.Text.Lazy.Encoding as TextEncoding

-- time
import Data.Time (Day)
import qualified Data.Time as Time


data Article = Article
  { articleArticleType :: ArticleType
  , articleAuthor :: Maybe Text
  , articleDate :: Day
  , articlePublication :: Publication
  , articleTitle :: Text
  , articleUrl :: Url
  }
  deriving (Eq, Generic, Show)

instance FromJSON Article where
  parseJSON =
    Aeson.genericParseJSON Aeson.defaultOptions
      { Aeson.fieldLabelModifier = Aeson.camelTo2 '-' . drop 7 }

instance ToJSON Article where
  toJSON =
    Aeson.genericToJSON Aeson.defaultOptions
      { Aeson.fieldLabelModifier = Aeson.camelTo2 '-' . drop 7 }


data ArticleType
  = Column
  | Editorial
  deriving (Eq, Generic, Show)

instance FromJSON ArticleType where
  parseJSON =
    Aeson.genericParseJSON Aeson.defaultOptions
      { Aeson.constructorTagModifier = Aeson.camelTo2 '-' }

instance ToJSON ArticleType where
  toJSON =
    Aeson.genericToJSON Aeson.defaultOptions
      { Aeson.constructorTagModifier = Aeson.camelTo2 '-' }


data Publication
  = ElColombiano
  | ElEspectador
  | ElTiempo
  deriving (Bounded, Enum, Eq, Generic, Show)

instance FromJSON Publication where
  parseJSON =
    Aeson.genericParseJSON Aeson.defaultOptions
      { Aeson.constructorTagModifier = Aeson.camelTo2 '-' }

instance ToJSON Publication where
  toJSON =
    Aeson.genericToJSON Aeson.defaultOptions
      { Aeson.constructorTagModifier = Aeson.camelTo2 '-' }

publicationUri :: Publication -> URI
publicationUri publication =
  case publication of
    ElColombiano ->
      Uri.URI
        "https:" (Just (Uri.URIAuth "" "www.elcolombiano.com" "")) "" "" ""
    ElEspectador ->
      Uri.URI
        "https:" (Just (Uri.URIAuth "" "www.elespectador.com" "")) "" "" ""
    ElTiempo ->
      Uri.URI
        "https:" (Just (Uri.URIAuth "" "www.eltiempo.com" "")) "" "" ""


newtype Url = Url
  { urlUri :: URI
  }
  deriving (Eq, Generic, Show)

instance FromJSON Url where
  parseJSON =
    Aeson.withText "Url" $
      \text ->
        case Uri.parseURI (Text.unpack text) of
          Just uri ->
            pure (Url uri)
          Nothing ->
            fail ""

instance ToJSON Url where
  toJSON =
    toJSON . show . urlUri


main :: IO ()
main = do
  manager <- HttpClientTls.newTlsManager
  args <- getArgs
  articles0 <-
    case args of
      f:_ ->
        fromMaybe mempty <$> Aeson.decodeFileStrict f
      _ ->
        pure mempty
  articles <-
    for [minBound .. maxBound] $
      \publication -> do
        articles <- getArticles manager publication
        pure (fmap (toArticle articles0) articles)
  ByteString.Lazy.putStrLn (Aeson.encode (concat articles))


toArticle :: [Article] -> Article -> Article
toArticle articles0 article =
  case find (eq article) articles0 of
    Just article2 ->
      article { articleDate = articleDate article2 }
    Nothing ->
      article
  where
    eq a1 a2 =
      articleArticleType a1 == articleArticleType a2
        && articleAuthor a1 == articleAuthor a2
        && articlePublication a1 == articlePublication a2
        && articleTitle a1 == articleTitle a2


getArticles :: Manager -> Publication -> IO [Article]

getArticles manager ElColombiano = do
  day <- fmap Time.utctDay Time.getCurrentTime
  request <- HttpClient.parseRequest "https://www.elcolombiano.com/opinion/editoriales"
  response <- HttpClient.httpLbs request manager
  let lbs = HttpClient.responseBody response
  let
    tags = TagSoup.parseTags lbs
    as =
      dropWhile (TagSoup.~/= TagSoup.TagOpen "a" []) $
      dropWhile (TagSoup.~/= TagSoup.TagOpen "div" [("class", "container-editorial_destacada")]) tags
    title =
      dropWhile (TagSoup.~/= TagSoup.TagOpen "span" []) as
  let s = ByteString.Lazy.unpack (TagSoup.fromAttrib (ByteString.Lazy.pack "href") (as !! 0))
  mEditorial <- case Uri.parseURIReference s of
    Just url -> do
      let
        article = Article
          { articleArticleType = Editorial
          , articleAuthor = Nothing
          , articleDate = day
          , articlePublication = ElColombiano
          , articleTitle = TextLazy.toStrict $ TextEncoding.decodeUtf8 $ safeFromTagText (title !! 1)
          , articleUrl = Url (Uri.relativeTo url (publicationUri ElColombiano))
          }
      pure (Just article)
    Nothing ->
      pure Nothing
  request2 <- HttpClient.parseRequest "https://www.elcolombiano.com/opinion/columnistas"
  response2 <- HttpClient.httpLbs request2 manager
  let tags2 = TagSoup.parseTags (HttpClient.responseBody response2)
  let
    articlesTags =
      TagSoup.partitions (TagSoup.~== "<div class=\"columnista columnista-redondo\">") tags2
    articles =
      flip fmap articlesTags $ \articleTags ->
        case dropWhile (TagSoup.~/= "<a>") $ dropWhile (TagSoup.~/= "<div class=right>") articleTags of
          a:more -> case dropWhile (TagSoup.~/= "<span>") more of
            _:t:more2 ->
              case dropWhile (TagSoup.~/= "<span class=name-bloguero>") more2 of
                _:au:_ ->
                  let hr = TagSoup.fromAttrib (ByteString.Lazy.pack "href") a in
                  case Uri.parseURIReference (ByteString.Lazy.unpack hr) of
                    Just uri ->
                      Just Article
                      { articleArticleType = Column
                      , articleAuthor =
                          TextLazy.toStrict . TextEncoding.decodeUtf8
                            <$> TagSoup.maybeTagText au
                      , articleDate = day
                      , articlePublication = ElColombiano
                      , articleTitle =
                          TextLazy.toStrict $ TextEncoding.decodeUtf8 $
                            safeFromTagText t
                      , articleUrl = Url (Uri.relativeTo uri (publicationUri ElColombiano))
                      }
                    Nothing ->
                      Nothing
                _ ->
                  Nothing
            _ ->
              Nothing
          _ ->
            Nothing
  pure (catMaybes (mEditorial:articles))

getArticles manager ElEspectador = do
  day <- fmap Time.utctDay Time.getCurrentTime
  request <- HttpClient.parseRequest "https://www.elespectador.com/opinion/editorial/"
  response <- HttpClient.httpLbs request manager
  let tags = TagSoup.parseTags (HttpClient.responseBody response)
  let
    as =
      dropWhile (TagSoup.~/= "<a>") $
      dropWhile (TagSoup.~/= TagSoup.TagOpen "h2" [("class", "Card-Title Title Title_main")]) tags
  let s = ByteString.Lazy.unpack (TagSoup.fromAttrib (ByteString.Lazy.pack "href") (as !! 0))
  mEditorial <- case Uri.parseURIReference s of
    Just uri -> do
      let
        article = Article
          { articleArticleType = Editorial
          , articleAuthor = Nothing
          , articleDate = day
          , articlePublication = ElEspectador
          , articleTitle = TextLazy.toStrict $ TextEncoding.decodeUtf8 $ safeFromTagText (as !! 1)
          , articleUrl = Url (Uri.relativeTo uri (publicationUri ElEspectador))
          }
      pure (Just article)
    Nothing ->
      pure Nothing
  request2 <- HttpClient.parseRequest "https://www.elespectador.com/opinion/columnistas/"
  response2 <- HttpClient.httpLbs request2 manager
  let tags2 = TagSoup.parseTags (HttpClient.responseBody response2)
  let
    articlesTags =
      TagSoup.partitions (TagSoup.~== "<div class=Card-Container>") tags2
    articles =
      flip fmap articlesTags $ \articleTags ->
        case dropWhile (TagSoup.~/= "<h2>") articleTags of
          _:a:t:_:_:_:_:au:_ ->
            let hr = TagSoup.fromAttrib (ByteString.Lazy.pack "href") a in
            case Uri.parseURIReference (ByteString.Lazy.unpack hr) of
              Just uri ->
                Just Article
                { articleArticleType = Column
                , articleAuthor = Just (TextLazy.toStrict $ TextEncoding.decodeUtf8 $ safeFromTagText au)
                , articleDate = day
                , articlePublication = ElEspectador
                , articleTitle = TextLazy.toStrict $ TextEncoding.decodeUtf8 $ safeFromTagText t
                , articleUrl = Url (Uri.relativeTo uri (publicationUri ElEspectador))
                }
              Nothing ->
                Nothing
          _ ->
            Nothing
  pure (catMaybes (mEditorial:articles))

getArticles manager ElTiempo = do
  day <- fmap Time.utctDay Time.getCurrentTime
  request <- HttpClient.parseRequest "https://www.eltiempo.com/opinion"
  response <- HttpClient.httpLbs request manager
  let tags = TagSoup.parseTags (HttpClient.responseBody response)
  let
    editorialTags =
      dropWhile (TagSoup.~/= "<a>")
        $ dropWhile (TagSoup.~/= "<h3>")
        $ dropWhile
          (\a -> a TagSoup.~/= "<article class=\"opinion-editorial-module \">"
              && a TagSoup.~/= "<article class=opinion-editorial-module>"
          ) tags
    mEditorial =
      case editorialTags of
        a:title:_ ->
          let href = TagSoup.fromAttrib (ByteString.Lazy.pack "href") a in
          case Uri.parseURIReference (ByteString.Lazy.unpack href) of
            Just uri ->
              Just Article
                { articleArticleType = Editorial
                , articleAuthor = Nothing
                , articleDate = day
                , articlePublication = ElTiempo
                , articleTitle = TextLazy.toStrict $ TextEncoding.decodeUtf8 $ safeFromTagText title
                , articleUrl = Url (Uri.relativeTo uri (publicationUri ElTiempo))
                }
            Nothing ->
              Nothing
        _ ->
          Nothing
  let
    dayTags =
      TagSoup.partitions
        (\a -> a TagSoup.~== "<div class=\"columnistas-day \">"
          || a TagSoup.~== "<div class=columnistas-day>"
        ) tags
        !! (fromEnum (Time.dayOfWeek day) - 1)
    dayId =
      TagSoup.fromAttrib (ByteString.Lazy.pack "data-ls-for") (dayTags !! 0)
    articlesTags =
      TagSoup.partitions (TagSoup.~== "<article>")
        $ takeWhile (TagSoup.~/= "<div class=opinion-author-articles>")
        $ drop 1
        $ head
        $ TagSoup.sections (TagSoup.~== ("<div id=" <> ByteString.Lazy.unpack dayId <> ">")) tags
  articles <- for articlesTags $ \articleTags -> do
    let
      authorTags =
        dropWhile
          (\a -> a TagSoup.~/= "<a class=\"author-name page-link \""
            && a TagSoup.~/= "<a class=\"author-name page-link\""
          ) articleTags
      titleTags =
        dropWhile
          (\a -> a TagSoup.~/= "<a class=\"title page-link \""
            && a TagSoup.~/= "<a class=\"title page-link\""
          ) articleTags
      mTitleHref =
        case titleTags of
          r:t:_ ->
            Just
              ( TagSoup.fromAttrib (ByteString.Lazy.pack "href") r
              , t
              )
          _ ->
            Nothing
    case (Uri.parseURIReference . ByteString.Lazy.unpack . fst =<< mTitleHref, fmap snd mTitleHref) of
      (Just uri, Just title) -> do
        let
          article = Article
            { articleArticleType = Column
            , articleAuthor = Just $ TextLazy.toStrict $ TextEncoding.decodeUtf8 $ safeFromTagText $ authorTags !! 1
            , articleDate = day
            , articlePublication = ElTiempo
            , articleTitle = TextLazy.toStrict $ TextEncoding.decodeUtf8 $ safeFromTagText title
            , articleUrl = Url (Uri.relativeTo uri (publicationUri ElTiempo))
            }
        pure (Just article)
      _ ->
        pure Nothing
  pure (catMaybes (mEditorial:articles))

safeFromTagText :: StringLike string => TagSoup.Tag string -> string
safeFromTagText tag =
  fromMaybe (TagSoup.innerText [tag]) (TagSoup.maybeTagText tag)
