module System exposing (Output(..), System, run, sampleSystem)

import Dict exposing (Dict)


type alias FileId =
    Int


type alias File =
    { id : FileId, parent : Maybe FileId, name : String, info : FileInfo }


type FileInfo
    = RealFileInfo { contents : String }
    | DirectoryInfo { children : List FileId }


type Output
    = OutputRegular String
    | OutputSpecial String
    | OutputError String


type alias System =
    { files : Dict FileId File, workingDirectory : FileId }


sampleSystem =
    { files =
        Dict.fromList
            [ ( 0
              , { id = 0
                , parent = Nothing
                , name = "/"
                , info = DirectoryInfo { children = [ 1, 2 ] }
                }
              )
            , ( 1
              , { id = 1
                , parent = Just 0
                , name = "documents"
                , info = DirectoryInfo { children = [ 3, 4 ] }
                }
              )
            , ( 2
              , { id = 2
                , parent = Just 0
                , name = "pictures"
                , info = DirectoryInfo { children = [] }
                }
              )
            , ( 3
              , { id = 3
                , parent = Just 1
                , name = "hello.txt"
                , info = RealFileInfo { contents = "Hello, world!\n" }
                }
              )
            , ( 4
              , { id = 4
                , parent = Just 1
                , name = "haiku.txt"

                -- Courtesy of https://www.gnu.org/fun/jokes/error-haiku.en.html
                , info = RealFileInfo { contents = "A file that big?\nIt might be very useful.\nBut now it is gone.\n" }
                }
              )
            ]
    , workingDirectory = 0
    }


getFile : System -> FileId -> Maybe File
getFile system fileId =
    Dict.get fileId system.files


binPwd : Binary
binPwd system words =
    if List.length words /= 0 then
        [ OutputError "pwd accepts no arguments." ]

    else
        let
            maybeD =
                getFile system system.workingDirectory
        in
        case maybeD of
            Just d ->
                [ OutputSpecial
                    (String.join
                        "/"
                        (List.map (\f -> f.name) (getParentEntries system d))
                    )
                ]

            Nothing ->
                [ OutputError "Working directory not found." ]


getParentEntries : System -> File -> List File
getParentEntries system file =
    case file.parent of
        Just parentId ->
            case getFile system parentId of
                Just parent ->
                    getParentEntries system parent ++ [ file ]

                Nothing ->
                    [ file ]

        Nothing ->
            [ file ]


type alias Binary =
    System -> List String -> List Output


binaries : Dict String Binary
binaries =
    Dict.fromList [ ( "pwd", binPwd ) ]


run : System -> String -> List Output
run system commandLine =
    let
        words =
            String.words commandLine
    in
    case List.head words of
        Just command ->
            case Dict.get command binaries of
                Just binary ->
                    binary system (Maybe.withDefault [] (List.tail words))

                Nothing ->
                    [ OutputError ("Command not found: " ++ command) ]

        Nothing ->
            []
