```
chip
       .-.
     <( o)
      (_|\
      - -
a simple nushell script to work with local LLM using llama.cpp
```
NOTE: it can't pass output to next command in pipeline

- Stateful: every prompt and answer from model is saved and it passed back to model on every new prompt
- Can be Stateless: with `-s` option the chat history can be disabled
- Supports images, text data and core nushell types passed as a pipeline input
- Manages llama.cpp instance, checks it's updates via GitHub Releases

# Commands
```nu
# stateful chat with model
chip <prompt>
chip -s <prompt>

# manage llama-server instance
chip sleep # kill llama-server
chip switch # start or switch llama-server instance with model from the list

# utils
chip add-model <alias> <path/to/model> [--mmProjFilePath <path/to/mmproj>]
chip check-engine
```

# models.toml config
```toml
[[models]]
name = "alias"

# every models entry contains required llama-server options to start this model  
# How to specify options? 
# what you need is to take a long option (`--` one) from llama-server help, 
# omit the first two dashes and this will be a valid parameter in this config file, 
# for example:
gpu-layers = 30 
ctx-size = 20000 
flash-attn = "on"  
cache-type-v = "q8_0" 
```

# Why
TLDR; I was a bit bored 

Why not? Well everybody writes a harneses for interacting with LLMs (remote or local ones) in different contexts, but here I wanted to use the data power of nushell and finally delete a Jan client, because found it a bit dull and I had a feeling that this  copy-paste-in-prompt process can be simplified without mcp. It was also interesting to write scripts for nushell and finaly start working with my shell, before I'd chosen this shell because of it's cross-platform and a bit posix nature and not this whole pipeline thing.
