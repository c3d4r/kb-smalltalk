"kb.st — Text-first kanban board. GNU Smalltalk."

"================================================================"
" KbItem                                                          "
"================================================================"
Object subclass: KbItem [
    | id title type status tags desc deps assignee priority created modified history |

    KbItem class >> new [ ^super new init ]

    init [
        tags := OrderedCollection new.
        deps := OrderedCollection new.
        history := OrderedCollection new.
    ]

    id [ ^id ]           id: v [ id := v ]
    title [ ^title ]     title: v [ title := v ]
    type [ ^type ]       type: v [ type := v ]
    status [ ^status ]   status: v [ status := v ]
    tags [ ^tags ]
    desc [ ^desc ]       desc: v [ desc := v ]
    deps [ ^deps ]
    assignee [ ^assignee ] assignee: v [ assignee := v ]
    priority [ ^priority ] priority: v [ priority := v ]
    created [ ^created ]   created: v [ created := v ]
    modified [ ^modified ] modified: v [ modified := v ]
    history [ ^history ]

    addTag: v [ (tags includes: v) ifFalse: [tags add: v] ]
    removeTag: v [ tags remove: v ifAbsent: [] ]
    addDep: v [ (deps includes: v) ifFalse: [deps add: v] ]
    addHistory: v [ history add: v ]

    moveTo: lane [
        | old |
        old := status.
        status := lane.
        modified := self class dateStamp.
        old isNil ifFalse: [
            history add: (self class dateStamp, ' ', old, ' -> ', lane)
        ]
    ]

    touch [ modified := self class dateStamp ]

    KbItem class >> dateStamp [
        | d |
        d := Date today.
        ^(self pad: d year to: 4), '-',
         (self pad: d month to: 2), '-',
         (self pad: d dayOfMonth to: 2)
    ]

    KbItem class >> pad: n to: w [
        | s |
        s := n printString.
        [s size < w] whileTrue: [s := '0', s].
        ^s
    ]

    printBrief [ ^'[', id, '] ', type, ': ', title ]

    serializeOn: s [
        s nextPutAll: '[', id, '] ', type, ': ', title; nl.
        s nextPutAll: '  status: ', status; nl.
        tags isEmpty ifFalse: [
            s nextPutAll: '  tags: '.
            tags do: [:t | s nextPutAll: t] separatedBy: [s nextPutAll: ', '].
            s nl
        ].
        priority isNil ifFalse: [s nextPutAll: '  priority: ', priority; nl].
        assignee isNil ifFalse: [s nextPutAll: '  assignee: ', assignee; nl].
        deps isEmpty ifFalse: [
            s nextPutAll: '  deps: '.
            deps do: [:d | s nextPutAll: d] separatedBy: [s nextPutAll: ', '].
            s nl
        ].
        (desc isNil not and: [desc isEmpty not]) ifTrue: [
            s nextPutAll: '  desc: |'; nl.
            (self class splitLines: desc) do: [:ln |
                s nextPutAll: '    ', ln; nl
            ]
        ].
        s nextPutAll: '  created: ', created; nl.
        s nextPutAll: '  modified: ', modified; nl.
        history isEmpty ifFalse: [
            s nextPutAll: '  history:'; nl.
            history do: [:h | s nextPutAll: '    ', h; nl]
        ]
    ]

    displayDetailed [
        | show |
        show := [:text | Transcript show: text; cr].
        show value: '[', id, '] ', type, ': ', title.
        show value: '  status: ', status.
        tags isEmpty ifFalse: [
            | ts |
            ts := WriteStream on: String new.
            tags do: [:t | ts nextPutAll: t] separatedBy: [ts nextPutAll: ', '].
            show value: '  tags: ', ts contents
        ].
        priority isNil ifFalse: [show value: '  priority: ', priority].
        assignee isNil ifFalse: [show value: '  assignee: ', assignee].
        deps isEmpty ifFalse: [
            | ds |
            ds := WriteStream on: String new.
            deps do: [:d | ds nextPutAll: d] separatedBy: [ds nextPutAll: ', '].
            show value: '  deps: ', ds contents
        ].
        (desc isNil not and: [desc isEmpty not]) ifTrue: [
            Transcript show: '  desc: |'; cr.
            (self class splitLines: desc) do: [:ln |
                Transcript show: '    ', ln; cr
            ]
        ].
        show value: '  created: ', created.
        show value: '  modified: ', modified.
        history isEmpty ifFalse: [
            Transcript show: '  history:'; cr.
            history do: [:h | Transcript show: '    ', h; cr]
        ]
    ]

    KbItem class >> splitLines: aString [
        | lines stream |
        lines := OrderedCollection new.
        stream := ReadStream on: aString.
        [stream atEnd] whileFalse: [
            lines add: (stream upTo: Character nl)
        ].
        ^lines
    ]
]

"================================================================"
" KbStore                                                         "
"================================================================"
Object subclass: KbStore [
    | filePath boardName lanes items |

    KbStore class >> on: aPath [ ^self new pvtInit: aPath ]

    pvtInit: aPath [
        filePath := aPath.
        items := OrderedCollection new.
        self load.
    ]

    boardName [ ^boardName ]
    lanes [ ^lanes ]
    items [ ^items ]

    "--- Persistence ---"
    load [
        | file |
        (File exists: filePath)
            ifTrue: [
                file := FileStream open: filePath mode: FileStream read.
                self parseStream: file.
                file close]
            ifFalse: [self setupDefaults]
    ]

    setupDefaults [
        boardName := 'default'.
        lanes := OrderedCollection withAll: #('backlog' 'doing' 'review' 'done').
    ]

    save [
        | file |
        file := FileStream open: filePath mode: FileStream write.
        file nextPutAll: '# Board: ', boardName; nl.
        file nextPutAll: '# Lanes: '.
        lanes do: [:l | file nextPutAll: l] separatedBy: [file nextPutAll: ', '].
        file nl; nl.
        items do: [:item | item serializeOn: file. file nl].
        file close
    ]

    "--- Parsing ---"
    parseStream: stream [
        | ctx |
        ctx := Array new: 2.
        ctx at: 1 put: #header.   "state"
        ctx at: 2 put: nil.       "current item"
        self setupDefaults.
        [stream atEnd] whileFalse: [
            self parseLine: (stream upTo: Character nl) ctx: ctx
        ]
    ]

    parseLine: line ctx: ctx [
        | trimmed indent state current |
        trimmed := line trimSeparators.
        trimmed isEmpty ifTrue: [^self].
        indent := self indentOf: line.
        state := ctx at: 1.
        current := ctx at: 2.

        "Board header"
        (self isPrefix: '# Board: ' of: trimmed) ifTrue: [
            boardName := (trimmed copyFrom: 10 to: trimmed size) trimSeparators.
            ^self].

        "Lanes header"
        (self isPrefix: '# Lanes: ' of: trimmed) ifTrue: [
            lanes := OrderedCollection new.
            (self splitComma: (trimmed copyFrom: 10 to: trimmed size))
                do: [:l | lanes add: l trimSeparators].
            ^self].

        "Item header [ID] type: title"
        (trimmed first = $[) ifTrue: [
            current := self parseItemHeader: trimmed.
            items add: current.
            ctx at: 1 put: #item.
            ctx at: 2 put: current.
            ^self].

        "Multi-line content (4+ space indent)"
        (indent >= 4 and: [current notNil]) ifTrue: [
            | content |
            content := line copyFrom: 5 to: line size.
            state = #desc ifTrue: [
                current desc isNil
                    ifTrue: [current desc: content]
                    ifFalse: [current desc: (current desc,
                        (String with: Character nl), content)]
            ].
            state = #history ifTrue: [
                current addHistory: content trimSeparators].
            ^self].

        "Field line (2+ space indent)"
        (indent >= 2 and: [current notNil]) ifTrue: [
            trimmed = 'history:' ifTrue: [
                ctx at: 1 put: #history. ^self].
            (self isPrefix: 'desc:' of: trimmed) ifTrue: [
                ctx at: 1 put: #desc. ^self].
            self parseField: trimmed on: current.
            ctx at: 1 put: #item]
    ]

    parseItemHeader: line [
        | item closeBracket rest colonIdx |
        item := KbItem new.
        closeBracket := line indexOf: (Character value: 93).
        item id: (line copyFrom: 2 to: closeBracket - 1).
        rest := (line copyFrom: closeBracket + 2 to: line size) trimSeparators.
        colonIdx := rest indexOf: $:.
        item type: (rest copyFrom: 1 to: colonIdx - 1) trimSeparators.
        item title: (rest copyFrom: colonIdx + 2 to: rest size) trimSeparators.
        ^item
    ]

    parseField: text on: item [
        | colonIdx key value |
        colonIdx := text indexOf: $:.
        colonIdx = 0 ifTrue: [^self].
        key := (text copyFrom: 1 to: colonIdx - 1) trimSeparators.
        value := (text copyFrom: colonIdx + 1 to: text size) trimSeparators.

        key = 'status'   ifTrue: [item status: value. ^self].
        key = 'priority' ifTrue: [item priority: value. ^self].
        key = 'assignee' ifTrue: [item assignee: value. ^self].
        key = 'created'  ifTrue: [item created: value. ^self].
        key = 'modified' ifTrue: [item modified: value. ^self].
        key = 'tags'     ifTrue: [
            (self splitComma: value) do: [:t | item addTag: t trimSeparators].
            ^self
        ].
        key = 'deps'     ifTrue: [
            (self splitComma: value) do: [:d | item addDep: d trimSeparators].
            ^self
        ]
    ]

    "--- Queries ---"
    find: anId [
        ^items detect: [:i | i id = anId] ifNone: [nil]
    ]

    itemsForLane: lane [
        ^items select: [:i | i status = lane]
    ]

    isBlocked: item [
        "An item is blocked if any of its deps are not done"
        item deps isEmpty ifTrue: [^false].
        ^item deps anySatisfy: [:depId |
            | dep |
            dep := self find: depId.
            dep isNil or: [dep status ~= 'done']
        ]
    ]

    blockedItems [
        ^items select: [:i | self isBlocked: i]
    ]

    blockingDeps: item [
        "Return the deps that are blocking this item"
        ^item deps select: [:depId |
            | dep |
            dep := self find: depId.
            dep isNil or: [dep status ~= 'done']
        ]
    ]

    "--- Mutations ---"
    addItem: aType title: aTitle options: opts [
        | item v |
        item := KbItem new.
        item id: self nextId.
        item type: aType.
        item title: aTitle.
        item status: (opts at: 'lane' ifAbsent: ['backlog']).
        item created: KbItem dateStamp.
        item modified: KbItem dateStamp.
        v := opts at: 'tag' ifAbsent: [nil].
        v isNil ifFalse: [item addTag: v].
        v := opts at: 'priority' ifAbsent: [nil].
        v isNil ifFalse: [item priority: v].
        v := opts at: 'assignee' ifAbsent: [nil].
        v isNil ifFalse: [item assignee: v].
        item addHistory: (KbItem dateStamp, ' created').
        items add: item.
        ^item
    ]

    moveItem: anId to: lane [
        | item |
        item := self find: anId.
        item isNil ifTrue: [^nil].
        (lanes includes: lane) ifFalse: [^nil].
        item moveTo: lane.
        ^item
    ]

    nextId [
        | max |
        max := 0.
        items do: [:item |
            | numPart n |
            numPart := item id copyFrom: 5 to: item id size.
            [n := numPart asInteger.
             n > max ifTrue: [max := n]]
                on: Error do: [:e | ]
        ].
        ^'KAN-', (KbItem pad: max + 1 to: 3)
    ]

    "--- Helpers ---"
    indentOf: line [
        | i |
        line isEmpty ifTrue: [^0].
        i := 1.
        [i <= line size and: [(line at: i) = $ ]] whileTrue: [i := i + 1].
        ^i - 1
    ]

    splitComma: str [
        | result start |
        result := OrderedCollection new.
        start := 1.
        1 to: str size do: [:i |
            (str at: i) = $, ifTrue: [
                result add: (str copyFrom: start to: i - 1).
                start := i + 1
            ]
        ].
        start <= str size ifTrue: [
            result add: (str copyFrom: start to: str size)
        ].
        ^result
    ]

    isPrefix: prefix of: str [
        ^str size >= prefix size and:
            [(str copyFrom: 1 to: prefix size) = prefix]
    ]
]

"================================================================"
" KbCli                                                           "
"================================================================"
Object subclass: KbCli [
    | store |

    KbCli class >> run: args [ self new pvtRun: args ]

    KbCli class >> usage [
        Transcript
            show: 'Usage: gst -f kb.st <command> [args]'; cr; cr;
            show: 'Commands:'; cr;
            show: '  add <type> "<title>" [--tag=X] [--priority=X] [--lane=X]'; cr;
            show: '  move <id> <lane>'; cr;
            show: '  show <id>'; cr;
            show: '  ls [--lane=X] [--tag=X] [--type=X] [--assignee=X]'; cr;
            show: '  board'; cr;
            show: '  edit <id> [--title=X] [--priority=X] [--tag+=X] [--tag-=X]'; cr;
            show: '  log <id>'; cr;
            show: '  blocked'; cr
    ]

    pvtRun: args [
        | cmd rest |
        store := KbStore on: 'kb.txt'.
        cmd := args first.
        rest := args size > 1
            ifTrue: [args copyFrom: 2 to: args size]
            ifFalse: [#()].

        cmd = 'add'   ifTrue: [^self cmdAdd: rest].
        cmd = 'move'  ifTrue: [^self cmdMove: rest].
        cmd = 'show'  ifTrue: [^self cmdShow: rest].
        cmd = 'ls'    ifTrue: [^self cmdLs: rest].
        cmd = 'board' ifTrue: [^self cmdBoard].
        cmd = 'edit'  ifTrue: [^self cmdEdit: rest].
        cmd = 'log'     ifTrue: [^self cmdLog: rest].
        cmd = 'blocked' ifTrue: [^self cmdBlocked].

        self class usage
    ]

    cmdAdd: args [
        | parsed pos opts item |
        parsed := self parseOpts: args.
        pos := parsed first.
        opts := parsed last.
        pos size < 2 ifTrue: [
            Transcript show: 'Usage: kb add <type> "<title>" [--tag=X] [--priority=X] [--lane=X]'; cr.
            ^self
        ].
        item := store addItem: pos first title: pos second options: opts.
        store save.
        Transcript show: 'Created ', item printBrief; cr
    ]

    cmdMove: args [
        | item |
        args size < 2 ifTrue: [
            Transcript show: 'Usage: kb move <id> <lane>'; cr. ^self
        ].
        item := store moveItem: args first to: args second.
        item isNil ifTrue: [
            Transcript show: 'Error: item not found or invalid lane'; cr. ^self
        ].
        store save.
        Transcript show: 'Moved ', item printBrief, ' -> ', args second; cr
    ]

    cmdShow: args [
        | item |
        args isEmpty ifTrue: [
            Transcript show: 'Usage: kb show <id>'; cr. ^self
        ].
        item := store find: args first.
        item isNil ifTrue: [
            Transcript show: 'Error: item ', args first, ' not found'; cr. ^self
        ].
        item displayDetailed
    ]

    cmdLs: args [
        | parsed opts filtered |
        parsed := self parseOpts: args.
        opts := parsed last.
        filtered := store items asOrderedCollection.
        (opts at: 'lane' ifAbsent: [nil]) isNil ifFalse: [
            filtered := filtered select: [:i | i status = (opts at: 'lane')]
        ].
        (opts at: 'tag' ifAbsent: [nil]) isNil ifFalse: [
            filtered := filtered select: [:i | i tags includes: (opts at: 'tag')]
        ].
        (opts at: 'type' ifAbsent: [nil]) isNil ifFalse: [
            filtered := filtered select: [:i | i type = (opts at: 'type')]
        ].
        (opts at: 'assignee' ifAbsent: [nil]) isNil ifFalse: [
            filtered := filtered select: [:i | i assignee = (opts at: 'assignee')]
        ].
        filtered isEmpty
            ifTrue: [Transcript show: '(no items)'; cr]
            ifFalse: [
                filtered do: [:item |
                    Transcript show: '  ', item printBrief; cr
                ]
            ]
    ]

    cmdBoard [
        Transcript show: '=== Board: ', store boardName, ' ==='; cr; cr.
        store lanes do: [:lane |
            | laneItems |
            laneItems := store itemsForLane: lane.
            Transcript show: '--- ', lane, ' (', laneItems size printString, ') ---'; cr.
            laneItems isEmpty
                ifTrue: [Transcript show: '  (empty)'; cr]
                ifFalse: [
                    laneItems do: [:item |
                        | marker |
                        marker := (store isBlocked: item)
                            ifTrue: [' [BLOCKED]'] ifFalse: [''].
                        Transcript show: '  ', item printBrief, marker; cr
                    ]
                ].
            Transcript cr
        ]
    ]

    cmdEdit: args [
        | id item parsed opts |
        args isEmpty ifTrue: [
            Transcript show: 'Usage: kb edit <id> [--title=X] [--priority=X] [--tag+=X] [--tag-=X]'; cr.
            ^self
        ].
        id := args first.
        item := store find: id.
        item isNil ifTrue: [
            Transcript show: 'Error: item ', id, ' not found'; cr. ^self
        ].
        parsed := self parseOpts: (args copyFrom: 2 to: args size).
        opts := parsed last.
        (opts at: 'title' ifAbsent: [nil]) isNil ifFalse: [
            item title: (opts at: 'title')].
        (opts at: 'desc' ifAbsent: [nil]) isNil ifFalse: [
            item desc: (opts at: 'desc')].
        (opts at: 'priority' ifAbsent: [nil]) isNil ifFalse: [
            item priority: (opts at: 'priority')].
        (opts at: 'assignee' ifAbsent: [nil]) isNil ifFalse: [
            item assignee: (opts at: 'assignee')].
        (opts at: 'tag+' ifAbsent: [nil]) isNil ifFalse: [
            item addTag: (opts at: 'tag+')].
        (opts at: 'tag-' ifAbsent: [nil]) isNil ifFalse: [
            item removeTag: (opts at: 'tag-')].
        (opts at: 'dep' ifAbsent: [nil]) isNil ifFalse: [
            item addDep: (opts at: 'dep')].
        item touch.
        store save.
        Transcript show: 'Updated ', item printBrief; cr
    ]

    cmdLog: args [
        | item |
        args isEmpty ifTrue: [
            Transcript show: 'Usage: kb log <id>'; cr. ^self
        ].
        item := store find: args first.
        item isNil ifTrue: [
            Transcript show: 'Error: item ', args first, ' not found'; cr. ^self
        ].
        Transcript show: 'History for ', item printBrief; cr.
        item history isEmpty
            ifTrue: [Transcript show: '  (no history)'; cr]
            ifFalse: [
                item history do: [:h | Transcript show: '  ', h; cr]
            ]
    ]

    cmdBlocked [
        | blocked |
        blocked := store blockedItems.
        blocked isEmpty
            ifTrue: [Transcript show: '(no blocked items)'; cr]
            ifFalse: [
                Transcript show: 'Blocked items:'; cr.
                blocked do: [:item |
                    | reasons |
                    reasons := store blockingDeps: item.
                    Transcript show: '  ', item printBrief; cr.
                    Transcript show: '    blocked by: '.
                    reasons do: [:depId |
                        | dep |
                        dep := store find: depId.
                        dep isNil
                            ifTrue: [Transcript show: depId, ' (missing)']
                            ifFalse: [Transcript show: depId, ' [', dep status, ']']
                    ] separatedBy: [Transcript show: ', '].
                    Transcript cr
                ]
            ]
    ]

    parseOpts: args [
        | pos opts |
        pos := OrderedCollection new.
        opts := Dictionary new.
        args do: [:arg |
            (arg size >= 2 and: [(arg copyFrom: 1 to: 2) = '--'])
                ifTrue: [
                    | eqIdx key value |
                    eqIdx := arg indexOf: $=.
                    eqIdx > 0
                        ifTrue: [
                            key := arg copyFrom: 3 to: eqIdx - 1.
                            value := arg copyFrom: eqIdx + 1 to: arg size.
                            opts at: key put: value]
                        ifFalse: [
                            opts at: (arg copyFrom: 3 to: arg size) put: 'true']
                ]
                ifFalse: [pos add: arg]
        ].
        ^Array with: pos with: opts
    ]
]

"================================================================"
" Entry point                                                     "
"================================================================"
| args |
args := Smalltalk arguments.
(args isNil or: [args isEmpty])
    ifTrue: [KbCli usage]
    ifFalse: [KbCli run: args]
