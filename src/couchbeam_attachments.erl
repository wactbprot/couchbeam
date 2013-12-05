%%% -*- erlang -*-
%%%
%%% This file is part of couchbeam released under the MIT license.
%%% See the NOTICE for more information.


%% @doc This module contains utilities to manage attachments

-module(couchbeam_attachments).

-include("couchbeam.hrl").

-export([add_inline/3, add_inline/4,
        delete_inline/2]).

%% @spec add_inline(Doc::json_obj(),Content::attachment_content(),
%%      AName::string()) -> json_obj()
%% @doc add attachment  to a doc and encode it. Give possibility to send attachments inline.
add_inline(Doc, Content, AName) ->
    ContentType = hackney_util:content_type(AName),
    add_inline(Doc, Content, AName, ContentType).

%% @spec add_inline(Doc::json_obj(), Content::attachment_content(),
%%      AName::string(), ContentType::string()) -> json_obj()
%% @doc add attachment  to a doc and encode it with ContentType fixed.
add_inline(Doc, Content, AName, ContentType) ->
    {Props} = Doc,
    Data = base64:encode(Content),
    Attachment = {couchbeam_util:to_binary(AName), {[{<<"content_type">>,
        couchbeam_util:to_binary(ContentType)}, {<<"data">>, Data}]}},

    Attachments1 = case proplists:get_value(<<"_attachments">>, Props) of
        undefined ->
            [Attachment];
        {Attachments} ->
            case set_attachment(Attachments, [], Attachment) of
                notfound ->
                    [Attachment|Attachments];
                A ->
                    A
                end
        end,
    couchbeam_doc:set_value(<<"_attachments">>, {Attachments1}, Doc).

%% @spec delete_inline(Doc::json_obj(), AName::string()) -> json_obj()
%% @doc delete an attachment record in doc. This is different from delete_attachment
%%      change is only applied in Doc object. Save_doc should be save to save changes.
delete_inline(Doc, AName) when is_list(AName) ->
    delete_inline(Doc, list_to_binary(AName));
delete_inline(Doc, AName) when is_binary(AName) ->
    {Props} = Doc,
    case proplists:get_value(<<"_attachments">>, Props) of
        undefined ->
            Doc;
        {Attachments} ->
            case proplists:get_value(AName, Attachments) of
                undefined ->
                    Doc;
                _ ->
                    Attachments1 = proplists:delete(AName, Attachments),
                    couchbeam_doc:set_value(<<"_attachments">>, {Attachments1}, Doc)
                end
        end.

% @private
set_attachment(Attachments, NewAttachments, Attachment) ->
    set_attachment(Attachments, NewAttachments, Attachment, false).
set_attachment([], Attachments, _Attachment, Found) ->
    case Found of
        true ->
            Attachments;
        false ->
            notfound
        end;
set_attachment([{Name, V}|T], Attachments, Attachment, Found) ->
    {AName, _} = Attachment,
    {Attachment1, Found1} = if
        Name =:= AName, Found =:= false ->
            {Attachment, true};
        true ->
            {{Name, V}, Found}
        end,
    set_attachment(T, [Attachment1|Attachments], Attachment, Found1).
