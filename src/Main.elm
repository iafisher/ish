module Main exposing (main)

import Browser
import Html as H exposing (Attribute, Html)
import Html.Attributes as A
import Html.Events as E
import Html.Keyed as Keyed
import Json.Decode as Json


main =
    Browser.sandbox { init = init, update = update, view = view }


type alias Model =
    { history : List String
    , value : String
    }


init : Model
init =
    { history = []
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
                { model | history = model.history ++ [ model.value ], value = "" }

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


makeChild : Int -> String -> ( String, Html Msg )
makeChild i s =
    ( "child" ++ String.fromInt i, H.pre [] [ H.code [] [ H.text s ] ] )


onKeyDown : (Int -> Msg) -> Attribute Msg
onKeyDown tagger =
    E.on "keydown" (Json.map tagger E.keyCode)
