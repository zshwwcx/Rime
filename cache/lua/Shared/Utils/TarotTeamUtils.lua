function packTarotTeamSearchList(searchList)
    return _script.cmsgpack.pack(searchList)
end

function unpackTarotTeamSearchList(searchList)
    searchList = _script.cmsgpack.unpack(searchList)
    return searchList
end
