# chip
#       .-.
#     <( o)
#      (_|\
#     - -
# a parrot that can talk (and manage llama.cpp)

const SCRIPT_DIR = $"(path self .)/chip"
const LLAMA_PORT = 8080

export def main [prompt: string, schema?: record, --stateless (-s)] {
    if (server-pid) == null {
        print "chip is sleeping.."
        print "hint: chip switch"
        return null
    }

    let raw = $in

    mut history = []

    if not $stateless {
        $"($SCRIPT_DIR)/.chat" | path exists |
            if $in { $history = open $"($SCRIPT_DIR)/.chat" | from json }
    }

    $history = $raw | describe -n | match $in {
        "nothing" => {
            $history | append {
                role: "user",
                content: $prompt
            }
        },

        "string" => {
            $history | append {
                role: "user",
                content: [
                    { type: "text", text: $prompt },
                    { type: "text", text: $raw }
                ]
            }
        },

        "binary" => {
            # available files
            [
                # jpeg start
                0x[ff d8 ff e0]
                0x[FF D8 FF DB]
                0x[FF D8 FF EE]
                0x[FF D8 FF E1]
                # jpeg end

                0x[89 50 4E 47 0D 0A 1A 0A] # png
                # ([0x[52 49 46 46] $length 0x[57 45 42 50]] | bytes collect) webp
            ] | where ($raw | bytes starts-with $it) |
                is-empty | if $in { error make "Please pass JPEG or PNG data" }

            $history | append {
                role: "user",
                content: [
                    { type: "text", text: $prompt },
                    { type: "image_url" image_url: { url: $"data:image/png;base64,($raw | encode base64)" }}
                ]
            }
        },

        _ => {
            $history | append {
                role: "user",
                content: [
                    { type: "text", text: $prompt },
                    { type: "text", text: ($raw | to json) }
                ]
            }
        }
    }

    let message = ask $history

    if not $stateless {
        $history |
            append { role: "assistant", content: $message } |
            to json | save -f $"($SCRIPT_DIR)/.chat"
    }

}

export def forget [] {
    print "chip: erasing my memory"
    print "memory eraser: *flash*"

    $"($SCRIPT_DIR)/.chat" | path exists |
            if $in { rm $"($SCRIPT_DIR)/.chat" }
}

def ask [history: list] {
    let model_id = http get $"http://localhost:($LLAMA_PORT)/v1/models" | $in.data.0.id

    {
        model: $model_id
        messages: [
            ...$history
        ]
        stream: true
    } | to json |
        (http post
            --content-type application/json
            $"http://localhost:($LLAMA_PORT)/v1/chat/completions" $in) | lines |
        generate {| line pending = {was_reasoning: false} |
            match ($line | split row -n 2 ":" | each { str trim }) {
                [$prefix $content] if $prefix == "data" => {
                    let $delta = $content | if $in != "[DONE]" { $in | from json | $in.choices.0.delta } else { {} }

                    # on first encounter of reasoning token, print only once
                    if 'reasoning_content' in $delta and not $pending.was_reasoning  {
                        # erase a line
                        print -n $"(ansi -e '2K')\r(ansi black_italic)Thinking...(ansi reset)"
                    }

                    if 'content' in $delta {
                        if $pending.was_reasoning {
                            print -n $"(ansi -e '2K')\r"
                        }

                        print -n $delta.content

                        return { next: ($pending | update was_reasoning false) out: $delta.content }
                    }

                    return {next:
                        ($pending | update was_reasoning { 'reasoning_content' in $delta })}
                }

                [$empty] if $empty == "" => {
                    return {next: $pending}
                }
            }
        } | collect { str join }
}

#
# llama-server managing
#

# Swaps a llama-server instance with a new instance,
# that has a different model and configuration
export def switch [] {
    let processId = server-pid

    if $processId != null {
       job kill $processId
    }

    let model = $"($SCRIPT_DIR)/models.toml" | path exists |
        if not $in { error make "can't find models.toml file" } else { open $"($SCRIPT_DIR)/models.toml" | get models | each { $in.name } } |
            input list "Select a model" | if $in == null { error make "specify model" } else $in

    let isVisionEnabled = ls | get name |
        path parse | get stem |
        where $it == $"($model).mmproj" | is-not-empty

    let opts = open $"($SCRIPT_DIR)/models.toml" | get models |
            where $it.name == $model | $in.0 |
            items {|opt, value|
                if $opt == "name" {
                    [-m $"($SCRIPT_DIR)/models/($model).gguf" ] |
                        if $isVisionEnabled { append [-mm $"($SCRIPT_DIR)/models/($model).mmproj.gguf"] } else $in
                } else { [$"--($opt)" $value] }
            } | flatten

    job spawn {
        open $"($SCRIPT_DIR)/.version" |
            (^$"($SCRIPT_DIR)/($in)/llama-server"
                ...$opts
                --port $LLAMA_PORT) out+err> $"($SCRIPT_DIR)/server.log"
    } | save -f $"($SCRIPT_DIR)/.process"
}

export def sleep [] {
    let processId = server-pid

    if $processId != null {
        job kill $processId
        rm $"($SCRIPT_DIR)/.process"
    } else {
        "chip is already sleeping..."
    }
}

def server-pid [] {
    $"($SCRIPT_DIR)/.process" | path exists |
        if $in { open $"($SCRIPT_DIR)/.process" | into int } else { -1 } |
        if $in in (job list | get id) { $in } else { null }
}

#
# utils
#

export def add-model [modelAlias: string, modelPath: path, --mmProjFilePath: path] {
    $"($SCRIPT_DIR)/models" | path exists | if not $in { mkdir $"($SCRIPT_DIR)/models"}

    mv $modelPath $"($SCRIPT_DIR)/models/($modelAlias).gguf"

    if $mmProjFilePath != null {
        mv $mmProjFilePath $"($SCRIPT_DIR)/models/($modelAlias).mmproj.gguf"
    }

    # try to pull config file
    let config = $"($SCRIPT_DIR)/models.toml" | path exists |
        if not $in { touch $"($SCRIPT_DIR)/models.toml"; {models: []} } else { open $"($SCRIPT_DIR)/models.toml" }

    $config | update models { append { name: $modelAlias } } | to toml | save -f $"($SCRIPT_DIR)/models.toml"
}

export def check-engine [] {
    if ($SCRIPT_DIR | path exists) {
        let version = open $"($SCRIPT_DIR)/.version"

        if ($"($SCRIPT_DIR)/($version)" | path exists) {
            ^$"($SCRIPT_DIR)/($version)/llama-server" --version

            let release = pull-llama-release
            if ($release.name != $version) {
                input $"New version ($release.name) is available, do you want to switch to it?" -d "no" |
                    if $in == "no" { return null }

                download-unpack-llama $release

                $release.name | save -f $"($SCRIPT_DIR)/.version"
            }
        } else {
            input $"Didn't find llama.cpp ($version) folder, do you want to download latest release?" -d "no" |
                if $in == "no" { return null }

            let release = pull-llama-release
            download-unpack-llama $release

            $release.name | save -f $"($SCRIPT_DIR)/.version"
        }
    } else {
        input "Didn't find llama-server, do you want to install it now? " -d "no" |
            if $in == "no" { return null }

        let release = pull-llama-release

        mkdir $SCRIPT_DIR
        download-unpack-llama $release

        $release.name | save $"($SCRIPT_DIR)/.version"
    }
}

def pull-llama-release [] {
    http get --headers {
        Accept: "application/vnd.github+json",
        X-GitHub-Api-Version: "2026-03-10"
    } https://api.github.com/repos/ggml-org/llama.cpp/releases | first
}

def download-unpack-llama [release] {
    # we need to exclude support library for cuda
    let files =  $release.assets | select name browser_download_url
    let selected = $files | where name !~ "cudart" | $in.name | input list "Select a package"

    mkdir $"($SCRIPT_DIR)/($release.name)"

    print "Downloading llama..."
    $files | where name == $selected | $in.browser_download_url.0 |
     http get $in | save --progress $"($SCRIPT_DIR)/($selected)" |
     tar -xf $"($SCRIPT_DIR)/($selected)" -C $"($SCRIPT_DIR)/($release.name)"

    print "and cleaning up..."
    rm $"($SCRIPT_DIR)/($selected)"

    if $selected =~ "win-cuda" {
        let cudartName = "cudart" | append $selected | str join "-" | str replace $'($release.name)-' ''

        print "Downloading cudart support libraries..."
        $files | where name == $cudartName | $in.browser_download_url.0 |
            http get $in | save --progress $"($SCRIPT_DIR)/($cudartName)" |
            tar -xf $"($SCRIPT_DIR)/($cudartName)" -C $"($SCRIPT_DIR)/($release.name)"

        print "and cleaning them too..."
        rm $"($SCRIPT_DIR)/($cudartName)"
    }

    print "chip: Got it"
}
