module Breakout exposing
    ( Model
    , Msg(..)
    , init
    , subscriptions
    , update
    , view
    )

-- IMPORTS

import Breakout.Paddle exposing (Direction, Paddle)
import Breakout.Window exposing (Window)
import Browser exposing (Document)
import Browser.Events
import Html exposing (Html)
import Html.Attributes
import Json.Decode
import Set
import Svg exposing (Svg)
import Svg.Attributes
import Util.Fps exposing (Time)
import Util.Keyboard exposing (Controls)



-- MODEL


type GameState
    = StartingScreen
    | PlayingScreen
    | EndingScreen


type alias Model =
    { deltaTimes : List Time
    , gameState : GameState
    , paddle : Paddle
    , playerKeyPress : Controls
    }



-- INIT


initialModel : Model
initialModel =
    { deltaTimes = Util.Fps.initialDeltaTimes
    , gameState = StartingScreen
    , paddle = Breakout.Paddle.initialPaddle
    , playerKeyPress = Util.Keyboard.initialKeys
    }


initialCommand : Cmd Msg
initialCommand =
    Cmd.none


init : () -> ( Model, Cmd Msg )
init _ =
    ( initialModel, initialCommand )



-- UPDATE


type Msg
    = BrowserAdvancedAnimationFrame Time
    | PlayerPressedKeyDown String
    | PlayerReleasedKey String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        BrowserAdvancedAnimationFrame time ->
            let
                paddleDirection =
                    Breakout.Paddle.playerKeyPressToDirection model.playerKeyPress
            in
            updatePaddle model.paddle paddleDirection Breakout.Window.globalWindow time model

        PlayerPressedKeyDown key ->
            ( updateKeyPress key model, Cmd.none )

        PlayerReleasedKey _ ->
            ( { model | playerKeyPress = Set.empty }, Cmd.none )



-- UPDATES


updateKeyPress : String -> Model -> Model
updateKeyPress key model =
    if Set.member key Util.Keyboard.validKeys then
        { model | playerKeyPress = Set.insert key model.playerKeyPress }

    else
        model


updatePaddle : Paddle -> Maybe Direction -> Window -> Time -> Model -> ( Model, Cmd Msg )
updatePaddle paddle maybeDirection window deltaTime model =
    ( { model
        | paddle =
            paddle
                |> Breakout.Paddle.updatePaddle maybeDirection deltaTime
                |> Breakout.Paddle.keepPaddleWithinWindow window
      }
    , Cmd.none
    )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ browserAnimationSubscription model.gameState
        , keyDownSubscription
        , keyUpSubscription
        ]


browserAnimationSubscription : GameState -> Sub Msg
browserAnimationSubscription gameState =
    case gameState of
        StartingScreen ->
            Browser.Events.onAnimationFrameDelta <| handleAnimationFrames

        PlayingScreen ->
            Browser.Events.onAnimationFrameDelta <| handleAnimationFrames

        EndingScreen ->
            Browser.Events.onAnimationFrameDelta <| handleAnimationFrames


handleAnimationFrames : Time -> Msg
handleAnimationFrames milliseconds =
    BrowserAdvancedAnimationFrame <| milliseconds / 1000


keyDownSubscription : Sub Msg
keyDownSubscription =
    Browser.Events.onKeyDown <| Json.Decode.map PlayerPressedKeyDown <| Util.Keyboard.keyDecoder


keyUpSubscription : Sub Msg
keyUpSubscription =
    Browser.Events.onKeyUp <| Json.Decode.map PlayerReleasedKey <| Util.Keyboard.keyDecoder



-- VIEW


view : Model -> Document Msg
view model =
    { title = "\u{1F6F8} Breakout"
    , body = [ viewMain model ]
    }


viewMain : Model -> Html Msg
viewMain model =
    Html.main_ [ Html.Attributes.class "bg-blue-400 h-full p-8" ]
        [ viewHeader
        , viewGame model
        ]


viewHeader : Html msg
viewHeader =
    Html.header [ Html.Attributes.class "flex justify-center" ]
        [ Html.h1 [] [ Html.text "Breakout" ] ]


viewGame : Model -> Html Msg
viewGame model =
    Html.section [ Html.Attributes.class "flex justify-center my-4" ]
        [ Html.div [ Html.Attributes.class "flex-shrink-0" ]
            [ viewSvg Breakout.Window.globalWindow model ]
        ]


viewSvg : Window -> Model -> Svg msg
viewSvg window model =
    let
        viewBoxString =
            [ window.x
            , window.y
            , window.width
            , window.height
            ]
                |> List.map String.fromFloat
                |> String.join " "
    in
    Svg.svg
        [ Svg.Attributes.viewBox viewBoxString
        , Svg.Attributes.width <| String.fromFloat window.width
        , Svg.Attributes.height <| String.fromFloat window.height
        ]
        [ Breakout.Window.viewGameWindow window
        , Breakout.Paddle.viewPaddle model.paddle
        , Breakout.Paddle.viewPaddleScore model.paddle.score window 10
        , Util.Fps.viewFps Util.Fps.On model.deltaTimes
        ]
