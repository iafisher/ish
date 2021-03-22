module Main exposing (main)

import Browser
import Html as H exposing (Attribute, Html)
import Html.Attributes as A
import Html.Events as E
import Html.Keyed as Keyed
import Json.Decode as Json
import System exposing (Output(..), System, run, sampleSystem)


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

            else
                model

        Input text ->
            { model | value = text }


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
    E.on "keydown" (Json.map tagger E.keyCode)
