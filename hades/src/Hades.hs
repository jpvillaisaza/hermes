{-# LANGUAGE DeriveGeneric #-}

module Hades where

-- aeson
import Data.Aeson (FromJSON(..), ToJSON(..))
import qualified Data.Aeson as Aeson

-- base
import GHC.Generics (Generic)

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
  deriving (Eq, Generic, Show)

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
  articles1 <- getArticles manager ElColombiano
  articles2 <- getArticles manager ElEspectador
  ByteString.Lazy.putStrLn (Aeson.encode (articles1 <> articles2))


getArticles :: Manager -> Publication -> IO [Article]
getArticles manager ElColombiano = do
  day <- fmap Time.utctDay Time.getCurrentTime
  request <- HttpClient.parseRequest "https://www.elcolombiano.com/opinion/editoriales"
  response <- HttpClient.httpLbs request manager
  let lbs = HttpClient.responseBody response
  let
    tags = TagSoup.parseTags lbs
    as =
      dropWhile (TagSoup.~/= (TagSoup.TagOpen "a" [])) $
      dropWhile (TagSoup.~/= (TagSoup.TagOpen "div" [("class", "editorial left")])) tags
    title =
      dropWhile (TagSoup.~/= (TagSoup.TagOpen "span" [])) as
  let s = ByteString.Lazy.unpack (TagSoup.fromAttrib (ByteString.Lazy.pack "href") (as !! 0))
  case Uri.parseURIReference s of
    Just url -> do
      let
        article = Article
          { articleArticleType = Editorial
          , articleAuthor = Nothing
          , articleDate = day
          , articlePublication = ElColombiano
          , articleTitle = TextLazy.toStrict $ TextEncoding.decodeUtf8 $ TagSoup.fromTagText (title !! 1)
          , articleUrl = Url (Uri.relativeTo url (publicationUri ElColombiano))
          }
      pure [article]
    Nothing ->
      pure mempty
getArticles manager ElEspectador = do
  day <- fmap Time.utctDay Time.getCurrentTime
  request <- HttpClient.parseRequest "https://www.elespectador.com/opinion/editorial/"
  response <- HttpClient.httpLbs request manager
  let tags = TagSoup.parseTags (HttpClient.responseBody response)
  let
    as =
      dropWhile (TagSoup.~/= "<a>") $
      dropWhile (TagSoup.~/= (TagSoup.TagOpen "h2" [("class", "Card-Title Title Title_main")])) tags
  let s = ByteString.Lazy.unpack (TagSoup.fromAttrib (ByteString.Lazy.pack "href") (as !! 0))
  case Uri.parseURIReference s of
    Just uri -> do
      let
        article = Article
          { articleArticleType = Editorial
          , articleAuthor = Nothing
          , articleDate = day
          , articlePublication = ElEspectador
          , articleTitle = TextLazy.toStrict $ TextEncoding.decodeUtf8 $ TagSoup.fromTagText (as !! 1)
          , articleUrl = Url (Uri.relativeTo uri (publicationUri ElEspectador))
          }
      pure [article]
    Nothing ->
      pure mempty
