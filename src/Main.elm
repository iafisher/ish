module Main exposing (main)

import Browser
import Html as H exposing (Attribute, Html)
import Html.Attributes as A
import Html.Events as E
import Html.Keyed as Keyed
import Json.Decode as Json
import System exposing (File, FileInfo(..), Output(..), System, getFile, getFileByName, run, sampleSystem)


main =
    Browser.sandbox { init = init, update = update, view = view }


type alias HistoryEntry =
    { prompt : String
    , output : List Output
    }


type alias Model =
    { system : System
    , history : List HistoryEntry
    , value : String
    }


init : Model
init =
    { system = sampleSystem
    , history = []
    , value = ""
    }


type Msg
    = KeyDown Int
    | Input String


update : Msg -> Model -> Model
update msg model =
    case msg of
        KeyDown key ->
            if key == 13 then
                let
                    ( newSystem, output ) =
                        run model.system model.value
                in
                { model
                    | history =
                        model.history
                            ++ [ { prompt = model.value, output = output } ]
                    , value = ""
                    , system = newSystem
                }

            else if key == 9 then
                { model | value = model.value ++ Maybe.withDefault "" (autocomplete model.system model.value) }

            else
                model

        Input text ->
            { model | value = text }


autocomplete : System -> String -> Maybe String
autocomplete system value =
    case value |> String.words |> List.filter (\s -> not (String.isEmpty s)) |> List.reverse |> List.head of
        Just lastWord ->
            case lastWord |> String.indices "/" |> List.reverse |> List.head of
                Just lastSlashIndex ->
                    getFileByName
                        system
                        (String.slice 0 lastSlashIndex lastWord)
                        |> Maybe.andThen
                            (\parent ->
                                getAutocompletion
                                    system
                                    parent
                                    (String.dropLeft (lastSlashIndex + 1) lastWord)
                            )

                Nothing ->
                    getAutocompletion system system.workingDirectory lastWord

        Nothing ->
            Nothing


getAutocompletion : System -> File -> String -> Maybe String
getAutocompletion system directory name =
    case directory.info of
        DirectoryInfo { children } ->
            children
                |> List.filterMap (\childId -> getFile system childId)
                |> List.filter (\f -> String.startsWith name f.name)
                |> List.map (\f -> f.name)
                |> List.head
                |> Maybe.andThen (\fullName -> Just (String.dropLeft (String.length name) fullName))

        RealFileInfo _ ->
            Nothing


view : Model -> Html Msg
view model =
    Keyed.node "div"
        [ A.id "container" ]
        (List.indexedMap makeChild model.history
            ++ [ ( "input-box", H.div [ A.id "input-box" ] [ H.span [ A.id "prompt" ] [ H.text "> " ], H.input [ A.id "input", A.value model.value, onKeyDown KeyDown, E.onInput Input ] [] ] ) ]
        )


makeChild : Int -> HistoryEntry -> ( String, Html Msg )
makeChild i e =
    ( "child" ++ String.fromInt i
    , H.pre []
        [ H.code []
            ([ H.span [ A.class "prompt" ] [ H.text ("> " ++ e.prompt ++ "\n") ] ]
                ++ List.map outputToHtml e.output
            )
        ]
    )


outputToHtml : Output -> Html Msg
outputToHtml output =
    case output of
        OutputRegular s ->
            H.span [] [ H.text s ]

        OutputSpecial s ->
            H.span [ A.class "cartouche" ] [ H.text s ]

        OutputError s ->
            H.span [ A.class "error" ] [ H.text s ]


onKeyDown : (Int -> Msg) -> Attribute Msg
onKeyDown tagger =
    E.preventDefaultOn "keydown" (Json.map (\x -> ( tagger x, x == 9 )) E.keyCode)
