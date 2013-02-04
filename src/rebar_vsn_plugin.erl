%%% -*- mode: Erlang; fill-column: 80; comment-column: 75; -*-
%%% Copyright 2012 Erlware, LLC. All Rights Reserved.
%%%
%%% This file is provided to you under the Apache License,
%%% Version 2.0 (the "License"); you may not use this file
%%% except in compliance with the License.  You may obtain
%%% a copy of the License at
%%%
%%%   http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing,
%%% software distributed under the License is distributed on an
%%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%%% KIND, either express or implied.  See the License for the
%%% specific language governing permissions and limitations
%%% under the License.
%%%---------------------------------------------------------------------------
%%% @author Eric Merrit <ericbmerritt@gmail.com>
%%% @copyright (C) 2012, Eric Merrit
%%% @doc
%%% This module provides a reasonable way to get decent semver compatible vsn
%%% from the system. This uses the rebar post_compile hook to rewrite the app
%%% file metadata with the correct version.
-module(rebar_vsn_rel_plugin).
-export([pre_generate/2,
         post_generate/2
        ]).

%%============================================================================
%% API  
%%============================================================================
pre_generate(_Config, ReltoolFile) ->
    case rebar_rel_utils:is_rel_dir() of
        {true, ReltoolFile} ->
            Semver = get_semver(),
            case filelib:is_regular(ReltoolFile ++ ".bak") of
                false -> ok;
                true  ->
                    rebar_utils:abort("It seems that last generate failed. Please restore reltool.config from reltool.config.bak manually")
            end,
            case file:copy(ReltoolFile, ReltoolFile ++ ".bak") of
                {ok, _} -> ok;
                {error, Reason} ->
                    rebar_utils:abort("Failed to backup ~p: ~p~n", [ReltoolFile, Reason])
            end,
            
            [{sys, RelConfig}| Other] = get_reltool_release_info(ReltoolFile),
            NewRelConfig = lists:map(fun({rel, Rel, "semver", O}) ->
                                               {rel, Rel, Semver, O};
                                        ({rel, Rel, semver, O}) ->
                                               {rel, Rel, Semver, O};
                                          (O) ->
                                               O
                                       end, RelConfig),
            write_rel_file(ReltoolFile, [{sys, NewRelConfig} | Other]);
        false ->
            ok
    end.

post_generate(_Config, ReltoolFile) ->
    case rebar_rel_utils:is_rel_dir() of
        {true, ReltoolFile} ->
            case file:rename(ReltoolFile ++ ".bak", ReltoolFile) of
                ok ->
                    ok;
                {error, Reason} ->
                    rebar_utils:abort("Failed to restore from backup ~p: ~p~n", [ReltoolFile ++ ".bak", Reason])
            end;
        false ->
            ok
    end.            

get_reltool_release_info(ReltoolFile) when is_list(ReltoolFile) ->
    case file:consult(ReltoolFile) of
        {ok, ReltoolConfig} ->
            ReltoolConfig;
        _ ->
            rebar_utils:abort("Failed to parse ~s~n", [ReltoolFile])
    end.

%%============================================================================
%% Internal Functions
%%============================================================================
 
%% TODO: Fix error with os:cmd errors
get_semver() ->
    %% Get the tag timestamp and minimal ref from the system. The
    %% timestamp is really important from an ordering perspective.
    RawRef = os:cmd("git log -n 1 --pretty=format:'%h\n' "),

    {Tag, TagVsn} = parse_tags(),
    RawCount =
        case Tag of
            undefined ->
                os:cmd("git rev-list HEAD | wc -l");
            _ ->
                os:cmd(io_lib:format("git rev-list ~s..HEAD | wc -l",
                                     [Tag]))
        end,

    %% Cleanup the tag and the Ref information. Basically leading 'v's and
    %% whitespace needs to go away.
    Ref = re:replace(RawRef, "\\s", "", [global]),
    Count = erlang:iolist_to_binary(re:replace(RawCount, "\\s", "", [global])),

    %% Create the valid [semver](http://semver.org) version from the tag
    case Count of
        <<"0">> ->
            erlang:binary_to_list(erlang:iolist_to_binary(TagVsn));
        _ ->
            erlang:binary_to_list(erlang:iolist_to_binary([TagVsn, "+build.",
                                                           Count, ".", Ref]))
    end.

%%============================================================================
%% Internal Functions
%%============================================================================

write_rel_file(RelFile, RelTerms) ->
    Format = "%% Autogenerated~n" ++ string:copies("~p.~n", length(RelTerms)),
    file:write_file(RelFile, io_lib:fwrite(Format, RelTerms)).

parse_tags() ->
    first_valid_tag(os:cmd("git log --oneline --decorate  | fgrep \"tag: \" -1000")).

first_valid_tag(Line) ->
    case re:run(Line, "(\\(|\\s)tag:\\s(v([^,\\)]+))", [{capture, [2, 3], list}]) of
        {match,[Tag, Vsn]} ->
            {Tag, Vsn};
        nomatch ->
            {undefined, "0.0.0"}
    end.
