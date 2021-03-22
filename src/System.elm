module System exposing (File, FileInfo(..), Output(..), System, getFile, getFileByName, run, sampleSystem)

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
    { files : Dict FileId File, workingDirectory : File }


sampleWorkingDirectory =
    { id = 0
    , parent = Nothing
    , name = "/"
    , info = DirectoryInfo { children = [ 1, 2 ] }
    }


sampleSystem =
    { files =
        Dict.fromList
            [ ( 0
              , sampleWorkingDirectory
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
    , workingDirectory = sampleWorkingDirectory
    }


getFile : System -> FileId -> Maybe File
getFile system fileId =
    Dict.get fileId system.files


getFileByName : System -> String -> Maybe File
getFileByName system name =
    if name == "." then
        Just system.workingDirectory

    else if name == "/" then
        getFile system 0

    else
        let
            path =
                String.split "/" name
        in
        case List.head path of
            Just "" ->
                getFileByNameRecursive
                    system
                    (getFile system 0)
                    (Maybe.withDefault [] (List.tail path))

            Just "." ->
                getFileByNameRecursive
                    system
                    (Just system.workingDirectory)
                    (Maybe.withDefault [] (List.tail path))

            Just _ ->
                getFileByNameRecursive
                    system
                    (Just system.workingDirectory)
                    path

            Nothing ->
                Nothing


getFileByNameRecursive : System -> Maybe File -> List String -> Maybe File
getFileByNameRecursive system maybeParent path =
    case maybeParent of
        Just parent ->
            case List.head path of
                Just ".." ->
                    Maybe.withDefault
                        Nothing
                        (Maybe.map
                            (\grandparentId ->
                                getFileByNameRecursive
                                    system
                                    (getFile system grandparentId)
                                    (Maybe.withDefault [] (List.tail path))
                            )
                            parent.parent
                        )

                Just pathPart ->
                    getFileByNameRecursive
                        system
                        (getFileByNameNonRecursive system parent pathPart)
                        (Maybe.withDefault [] (List.tail path))

                Nothing ->
                    Just parent

        Nothing ->
            Nothing


getFileByNameNonRecursive : System -> File -> String -> Maybe File
getFileByNameNonRecursive system parent name =
    case parent.info of
        DirectoryInfo { children } ->
            children
                |> List.filterMap (\childId -> getFile system childId)
                |> List.filter (\f -> f.name == name)
                |> List.head

        RealFileInfo _ ->
            Nothing


binPwd : PureBinary
binPwd system words =
    if List.length words /= 0 then
        [ OutputError "pwd accepts no arguments." ]

    else
        [ OutputSpecial
            ("/"
                ++ String.join
                    "/"
                    (List.map (\f -> f.name) (getParentEntries system system.workingDirectory))
            )
        ]


binCd : Binary
binCd system words =
    if List.length words /= 1 then
        ( system, [ OutputError "cd requires exactly one argument." ] )

    else
        case words |> List.head |> Maybe.andThen (getFileByName system) of
            Just target ->
                ( { system | workingDirectory = target }, [] )

            Nothing ->
                ( system, [ OutputError "File not found." ] )


binShow : PureBinary
binShow system words =
    if List.length words > 1 then
        [ OutputError "show requires zero or one argument." ]

    else
        showFile system (getFileByName system (Maybe.withDefault "." (List.head words)))


showFile : System -> Maybe File -> List Output
showFile system maybeFile =
    case maybeFile of
        Just file ->
            case file.info of
                RealFileInfo { contents } ->
                    [ OutputRegular contents ]

                DirectoryInfo { children } ->
                    List.map
                        (\fileId ->
                            Maybe.withDefault
                                (OutputError "Invalid file ID.\n")
                                (Maybe.map
                                    (\f -> OutputSpecial (f.name ++ "\n"))
                                    (getFile system fileId)
                                )
                        )
                        children

        Nothing ->
            [ OutputError "File not found." ]


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
            []


type alias PureBinary =
    System -> List String -> List Output


type alias Binary =
    System -> List String -> ( System, List Output )


wrapBinary : PureBinary -> Binary
wrapBinary binary =
    \system words -> ( system, binary system words )


binaries : Dict String Binary
binaries =
    Dict.fromList [ ( "pwd", wrapBinary binPwd ), ( "show", wrapBinary binShow ), ( "cd", binCd ) ]


run : System -> String -> ( System, List Output )
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
                    ( system, [ OutputError ("Command not found: " ++ command) ] )

        Nothing ->
            ( system, [] )
