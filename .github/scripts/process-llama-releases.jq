def normalized_name:
  .name | ascii_downcase;

def asset_pair_key:
  normalized_name
  | sub("^cudart-"; "")
  | sub("^llama-b[0-9]+-"; "llama-");

def is_ui_asset:
  normalized_name | test("(^|[-_])ui([._-]|$)");

def classify_platform($name):
  if ($name | test("(^|-)win(-|\\.)")) then "windows"
  elif ($name | test("(^|-)macos(-|\\.)")) then "macos"
  elif ($name | test("android")) then "android"
  elif ($name | test("(^|-)ubuntu(-|\\.)|(^|-)linux(-|\\.)")) then "linux"
  else null
  end;

def classify_architecture($name):
  if ($name | test("(^|[-_])arm64([._-]|$)")) then "arm64"
  elif ($name | test("(^|[-_])x64([._-]|$)|x86_64")) then "x64"
  elif ($name | test("(^|[-_])s390x([._-]|$)")) then "s390x"
  else "unknown"
  end;

def classify_runtime($name):
  if ($name | test("cuda")) then "CUDA"
  elif ($name | test("vulkan")) then "Vulkan"
  elif ($name | test("rocm")) then "ROCm"
  elif ($name | test("sycl")) then "SYCL"
  elif ($name | test("openvino")) then "OpenVINO"
  elif ($name | test("opencl")) then "OpenCL"
  elif ($name | test("snapdragon")) then "Snapdragon"
  elif ($name | test("zdnn")) then "ZDNN"
  elif ($name | test("metal")) then "Metal"
  elif ($name | test("(^|-)cpu(-|\\.)|(^|-)bin(-|\\.)")) then "CPU"
  else "Other"
  end;

def classify_asset:
  . as $asset
  | ($asset | normalized_name) as $name
  | {
      name: $asset.name,
      download_url: $asset.browser_download_url,
      size: $asset.size,
      kind: (if ($name | test("^cudart-")) then "support-library" else "runtime" end),
      platform: classify_platform($name),
      architecture: classify_architecture($name),
      runtime: classify_runtime($name)
    };

def attach_support_libraries($assets):
  . as $runtime
  | . + {
      support_libraries: [
        $assets[]
        | select(.kind == "support-library")
        | select(asset_pair_key == ($runtime | asset_pair_key))
      ]
    };

def artifact_bundle:
  {
    artifact: {name, link: .download_url, size},
    support_libraries: [
      .support_libraries[] | {name, link: .download_url, size}
    ]
  };

def architecture_index:
  group_by(.architecture)
  | map({
      key: .[0].architecture,
      value: map(artifact_bundle)
    })
  | from_entries;

def runtime_index:
  group_by(.runtime)
  | map({
      key: .[0].runtime,
      value: architecture_index
    })
  | from_entries;

def platform_index:
  [
    .assets[]
    | select(is_ui_asset | not)
    | classify_asset
    | select(.platform != null)
  ] as $assets
  | [
      $assets[]
      | select(.kind == "runtime")
      | attach_support_libraries($assets)
    ]
  | sort_by(.platform, .runtime, .architecture, .name)
  | group_by(.platform)
  | map({
      key: .[0].platform,
      value: {
        available_runtimes: runtime_index
      }
    })
  | from_entries;

{
  source: $source,
  fetched_at: $fetched_at,
  releases: [.[] | {
    name,
    tag_name,
    html_url,
    published_at,
    platforms: platform_index
  }]
}