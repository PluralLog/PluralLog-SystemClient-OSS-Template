# PluralLog Export/Import JSON Schema

This documents the complete JSON structure used by PluralLog's export and import
functionality. All data lives in a single JSON object stored at
`plurallog_data.json` on device, internal storage (data loss seems caused by some platforms mapping our request to external?).

## Root Object

```json
{
  "config":           { ... },
  "members":          [ ... ],
  "switchEvents":     [ ... ],
  "channels":         [ ... ],
  "messages":         [ ... ],
  "journal":          [ ... ],
  "polls":            [ ... ],
  "customFieldDefs":  [ ... ],
  "frontMessages":    [ ... ],
  "folders":          [ ... ]
}
```

All arrays are optional. Missing keys are treated as empty.

## config (single object)

| Field                  | Type           | Description                    |
|------------------------|----------------|--------------------------------|
| systemName             | string\|null   | Display name for the system    |
| analyticsEnabled       | 0\|1           | Whether analytics are enabled  |
| moodTrackingEnabled    | 0\|1           | Whether mood tracking is on    |
| journalPromptsEnabled  | 0\|1           | Whether journal prompts show   |
| onboardingComplete     | 0\|1           | Whether onboarding is done     |
| federationEnabled      | 0\|1           | Federation connection active   |
| federationServerUrl    | string\|null   | Relay server URL               |
| federationHandle       | string\|null   | User handle on the server      |
| federationUserId       | string\|null   | UUID assigned by the server    |

## members[] (merged by "id")

| Field             | Type           | Description                                    |
|-------------------|----------------|------------------------------------------------|
| id                | string         | UUID                                           |
| name              | string         | Display name                                   |
| pronouns          | string\|null   | Pronouns                                       |
| role              | string\|null   | System role                                    |
| description       | string\|null   | Short description                              |
| color             | integer        | Flutter Color.value (0xAARRGGBB)               |
| avatarEmoji       | string\|null   | Emoji used as avatar                           |
| profileImagePath  | string\|null   | Local filesystem path to profile image         |
| profileMarkdown   | string\|null   | Markdown-formatted extended profile            |
| customFields      | string         | JSON-encoded Map<String,String>                |
| parentMemberId    | string\|null   | Parent member ID (subsystem hierarchy)         |
| createdAt         | integer        | Milliseconds since Unix epoch                  |
| vault             | string         | JSON-encoded Map<String,String> private data   |

## switchEvents[] (merged by "id")

| Field         | Type           | Description                              |
|---------------|----------------|------------------------------------------|
| id            | string         | UUID                                     |
| memberId      | string         | Primary fronter member ID                |
| startTime     | integer        | Milliseconds since epoch                 |
| endTime       | integer\|null  | null = still active                      |
| notes         | string\|null   | Optional notes                           |
| cofronterIds  | string         | Comma-separated member IDs, or ""        |

## channels[] (merged by "id")

| Field | Type         | Description     |
|-------|--------------|-----------------|
| id    | string       | e.g. "ch_general" |
| name  | string       | Channel name    |
| icon  | string\|null | Emoji           |

## messages[] (merged by "id")

| Field     | Type    | Description                          |
|-----------|---------|--------------------------------------|
| id        | string  | UUID                                 |
| channelId | string  | FK to channels[].id                  |
| authorId  | string  | FK to members[].id                   |
| text      | string  | Message text                         |
| timestamp | integer | Milliseconds since epoch             |
| pinned    | 0\|1    | Whether message is pinned            |
| reactions | string  | Comma-separated emoji, or ""         |

## journal[] (merged by "id")

| Field    | Type         | Description                                 |
|----------|--------------|---------------------------------------------|
| id       | string       | UUID                                        |
| authorId | string       | FK to members[].id                          |
| text     | string       | Entry text                                  |
| emotion  | string\|null | "happy","neutral","sad","anxious","angry","dissociated" |
| timestamp| integer      | Milliseconds since epoch                    |
| tags     | string       | Comma-separated tags, or ""                 |
| hidden   | 0\|1         | Hidden entries excluded from federation     |

## polls[] (merged by "id")

| Field     | Type    | Description                                  |
|-----------|---------|----------------------------------------------|
| id        | string  | UUID                                         |
| question  | string  | Poll question                                |
| options   | string  | "\|\|\|"-delimited option strings             |
| votes     | string  | Comma-separated "memberId:optionIndex" pairs |
| createdAt | integer | Milliseconds since epoch                     |
| closed    | 0\|1    | Whether poll is closed                       |

## customFieldDefs[] (merged by "id")

| Field     | Type         | Description                               |
|-----------|--------------|-------------------------------------------|
| id        | string       | UUID                                      |
| name      | string       | Display name                              |
| fieldType | string       | "text"\|"markdown"\|"boolean"\|"choice"\|"image_url" |
| choices   | string\|null | "\|\|\|"-delimited choices (choice type)   |
| sortOrder | integer      | Display ordering                          |

## frontMessages[] (merged by "id")

Messages left by one member for another, displayed when the recipient fronts.
Purely client-side — never included in federation volumes.

| Field        | Type    | Description                    |
|--------------|---------|--------------------------------|
| id           | string  | UUID                           |
| fromMemberId | string  | FK to members[].id             |
| toMemberId   | string  | FK to members[].id             |
| text         | string  | Message content                |
| createdAt    | integer | Milliseconds since epoch       |
| read         | 0\|1    | Whether recipient has read it  |

## folders[] (merged by "id")

Organizational folders for grouping members. Purely client-side.

| Field      | Type         | Description                    |
|------------|--------------|--------------------------------|
| id         | string       | UUID                           |
| name       | string       | Display name                   |
| icon       | string\|null | Emoji icon                     |
| colorValue | integer      | Flutter Color.value            |
| memberIds  | string       | Comma-separated member IDs     |
| sortOrder  | integer      | Display ordering               |

## Notes on Federation Volumes

The federation volume sync serializes only: meta, members, fronts, journal,
chat, polls, analytics, vault. The `frontMessages` and `folders` keys are purely
local data and are never uploaded to the relay server.
