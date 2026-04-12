```
chip
       .-.
     <( o)
      (_|\
      - -
a simple LoC nushell script to work with local LLM using llama.cpp
```
NOTE: it can't pass output to next command in pipeline yet

- Stateful: every prompt and answer from model is saved and it passed back to model on every new prompt
- Can be Stateless: with `-s` option the chat history can be disabled
- Supports images, text data and core nushell types passed as a pipeline input
- Manages llama.cpp instance, checks it's updates via GitHub Releases

## Setup
```nu
http get https://raw.githubusercontent.com/mntcloud/chip/refs/heads/master/chip.nu | save your/preferable/path/to/chip.nu
```
Then add in your nushell config file a `use` command with path of the script and restart the shell
To get started just run `chip check-engine` and this what it will do:

1. Asks your permission to install llama.cpp release
2. Creates a folder in the same place, where the script is stored 
3. Lists all released artificats, except CUDA support libs, to select
4. Downloads a selected one
5. Unpacks in a folder with name of release and sets version in `.version` file

You can now run `add-model` and start server with `switch` command

## Commands
```nu
chip <prompt> # talk to model (stateful) 
chip -s <prompt> # stateless mode
chip forget # erase chat history

# manage llama-server instance
chip sleep # kill llama-server
chip switch # start or switch llama-server instance with model configuration from the list

# utils
chip add-model <alias> <path/to/model> [--mmProjFilePath <path/to/mmproj>]
chip check-engine
```

## models.toml config
```toml
[[models]]
name = "alias"

# every models entry contains required llama-server options to start this model  
# what you need is to take a long option (`--` one) from llama-server help, 
# omit the first two dashes and this will be a valid parameter in this config file, 
# for example:
gpu-layers = 30 
ctx-size = 20000 
flash-attn = "on"  
cache-type-v = "q8_0" 
```

#### Why
TLDR; I was a bit bored 

Why not? Well everybody writes a harneses for interacting with LLMs (remote or local ones) in different contexts, but here I wanted to use the data power of nushell and finally delete a Jan client, because found it a bit dull and I had a feeling that this  copy-paste-in-prompt process can be utilized a bit better. It was also interesting to write scripts for nushell and finaly start deeply working with my shell before that I'd chosen this shell because of it's cross-platform and a bit posix nature and not this whole pipeline thing.
