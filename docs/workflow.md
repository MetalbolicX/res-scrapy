# res-scrapy Workflow

This diagram illustrates the complete data flow through res-scrapy:

```mermaid
flowchart TD
    %% Input Layer
    subgraph Input["📥 Input Sources"]
        URL["🌐 URL\ncurl https://site.com"]
        FILE["📄 File\ncat page.html"]
        STDIN["⌨️  Stdin\necho '<html>...'"]
    end

    %% Processing Layer
    subgraph Process["⚙️  Processing"]
        PARSE["🔍 Parse HTML\nnode-html-parser"]
        SELECT["🎯 Match Selectors\nCSS Selectors"]
        EXTRACT["📤 Extract Data\n10 Field Types"]
    end

    %% Field Types Detail
    subgraph Fields["📋 Field Types"]
        TEXT["🔤 Text"]
        NUM["🔢 Number"]
        BOOL["✅ Boolean"]
        DATE["📅 DateTime"]
        URL_TYPE["🔗 URL"]
        ATTR["🏷️  Attribute"]
        HTML["📄 HTML"]
        JSON_TYPE["📊 JSON"]
        LIST["📃 List"]
        COUNT["🔢 Count"]
    end

    %% Output Layer
    subgraph Output["📤 Output"]
        JSON_OUT["📄 JSON Array\n[ {...}, {...} ]"]
        TABLE["📊 Table Mode\nCSV-like JSON"]
        ERROR["⚠️  Error Handling\nstderr + exit code"]
    end

    %% Connections
    URL --> PARSE
    FILE --> PARSE
    STDIN --> PARSE

    PARSE --> SELECT
    SELECT --> EXTRACT

    EXTRACT --> TEXT
    EXTRACT --> NUM
    EXTRACT --> BOOL
    EXTRACT --> DATE
    EXTRACT --> URL_TYPE
    EXTRACT --> ATTR
    EXTRACT --> HTML
    EXTRACT --> JSON_TYPE
    EXTRACT --> LIST
    EXTRACT --> COUNT

    TEXT --> JSON_OUT
    NUM --> JSON_OUT
    BOOL --> JSON_OUT
    DATE --> JSON_OUT
    URL_TYPE --> JSON_OUT
    ATTR --> JSON_OUT
    HTML --> JSON_OUT
    JSON_TYPE --> JSON_OUT
    LIST --> JSON_OUT
    COUNT --> JSON_OUT

    SELECT -.->|"--table flag"| TABLE
    EXTRACT -.->|"Invalid selector\nMissing field"| ERROR

    %% Styling
    style Input fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    style Process fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    style Fields fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    style Output fill:#f3e5f5,stroke:#6a1b9a,stroke-width:2px

    style PARSE fill:#c8e6c9,stroke:#2e7d32
    style SELECT fill:#c8e6c9,stroke:#2e7d32
    style EXTRACT fill:#c8e6c9,stroke:#2e7d32

    style JSON_OUT fill:#ce93d8,stroke:#6a1b9a
    style TABLE fill:#ce93d8,stroke:#6a1b9a
    style ERROR fill:#ffcdd2,stroke:#c62828
```

## 1. **Input Sources** (Blue)

HTML can come from anywhere:

- **URL**: Pipe curl output directly
- **File**: Read local HTML files
- **Stdin**: Echo or pipe HTML content

## 2. **Processing** (Green)

Three-stage pipeline:

- **Parse**: HTML is parsed into a traversable DOM
- **Select**: CSS selectors find target elements
- **Extract**: Data is extracted and transformed

## 3. **Field Types** (Orange)

10 powerful extraction types:

- **Text**: Clean text content
- **Number**: Parsed with currency stripping
- **Boolean**: True/false logic
- **DateTime**: Normalized dates
- **URL**: Resolved and validated links
- **Attribute**: Any HTML attribute
- **HTML**: Raw markup
- **JSON**: Embedded JSON-LD
- **List**: Arrays of values
- **Count**: Element counts

## 4. **Output** (Purple)

Flexible output options:

- **JSON Array**: Structured objects
- **Table Mode**: Quick table extraction
- **Error Handling**: Clear errors to stderr

## Key Features Shown

- 🔄 **Multi-source input**: URL, file, or stdin
- 🎯 **Schema-driven**: Define once, use everywhere
- 📊 **Type safety**: Automatic parsing and validation
- ⚡ **Fast**: Built for speed with ReScript
- 🛡️ **Reliable**: Proper error handling

---
