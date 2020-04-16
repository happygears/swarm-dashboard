module Components exposing (..)

import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Util exposing (..)
import Docker.Types exposing (..)
import Components.Networks as Networks

statusString : String -> String -> String
statusString state desiredState =
    if state == desiredState then
        state
    else
        state ++ " → " ++ desiredState

task : Service -> AssignedTask -> Html msg
task service { status, desiredState, containerSpec, slot, nodeId } =

    let
        classes =
            [ ( status.state, True )
            , ( "desired-" ++ desiredState, True )
            , ( "running-old", status.state == "running" && service.containerSpec.image /= containerSpec.image )
            ]

        slotLabel slot =
            case slot of
                Just s ->
                    toString s

                Nothing ->
                    ""
        serviceName service =
            case service of
                Just s ->
                    toString s

                Nothing ->
                    ""
        slotId = slotLabel slot
        nsid = String.slice 0 6 nodeId
        boxlabel = iff (slotId == "") nsid slotId

    in
        li [ classList classes, title (service.name ++ "." ++ boxlabel ++ "\n" ++ statusString status.state desiredState ) ]
            [ text boxlabel
            ]


serviceNode : Service -> TaskIndex -> Node -> Html msg
serviceNode service taskAllocations node =
    let
        tasks =
            Maybe.withDefault [] (Dict.get ( node.id, service.id ) taskAllocations)
    in
        td []
            [ ul [] (List.map (task service) tasks) ]


serviceRow : List Node -> TaskIndex -> Networks.Connections -> Service -> Html msg
serviceRow nodes taskAllocations networkConnections service =
    tr []
        (th [title(service.id)] [ text service.name ] :: (Networks.connections service networkConnections) :: (List.map (serviceNode service taskAllocations) nodes))


node : Node -> Html msg
node node =
    let
        leader =
            Maybe.withDefault False (Maybe.map .leader node.managerStatus)

        classes =
            [ ( "down", node.status.state == "down" )
            , ( "manager", node.role == "manager" )
            , ( "leader", leader )
            ]

        firstChar =
            String.slice 0 1 node.role

        nodeRoleFull =
            String.join " " [ node.role, iff leader "(leader)" "" ]


        nodeRole =
            String.join "" [ firstChar, iff leader "-L" "" ]

    in
        th [ classList classes, title(node.name ++ "\n" ++ nodeRoleFull ++ "\n" ++ node.status.address)]
            [ span [class "role"] [text nodeRole]

            ]
-- , span [class "address"] [text node.status.address]

swarmHeader : List Node -> List Network -> Html msg
swarmHeader nodes networks =
    tr [] ((th [] [ img [ src "docker_logo.svg" ] [] ]) :: Networks.header networks :: (nodes |> List.map node))




-- sort nodes, managers to the right
compareNodes : Node -> Node -> Order
compareNodes a b =
    case compare a.role b.role of
        LT ->
            GT
        GT ->
            LT
        _ ->
            EQ




swarmGrid : List Service -> List Node -> List Network -> TaskIndex -> Html msg
swarmGrid services nodes networks taskAllocations =
    let
        networkConnections =
            Networks.buildConnections services networks

        sortednodes =
            List.sortWith compareNodes nodes
    in
        table []
            [ thead [] [ swarmHeader sortednodes networks ]
            , tbody [] (List.map (serviceRow sortednodes taskAllocations networkConnections) services)
            ]
