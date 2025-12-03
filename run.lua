-- Aseprite FFMPEG Export Plugin
-- Exports the current sprite to MP4 video using FFMPEG

local error_messages = {
  no_active_sprite = "No active sprite. Please open a sprite first.",
  temp_dir_not_found = "ERROR: Could not find temp directory. Check your system TEMP/TMP environment variables.",
  temp_dir_creation_failed = "ERROR: Failed to create temporary directory.",
  sprite_frame_export_failed = "ERROR: Failed to export sprite frames.",
  batch_file_creation_failed = "ERROR: Could not create batch file.",
  output_file_not_specified = "Please specify an output file path.",
  ffmpeg_not_installed = "ERROR: FFMPEG export failed. Make sure FFMPEG is installed and in your system PATH.",
}

local function show_error(error_msg)
  print("[FFMPEG Export] ERROR: " .. error_msg)
  app.alert(error_msg)
end

local function cleanup_temp_dir(dir)
  -- Windows cleanup command
  local cmd = "rmdir /s /q \"" .. dir .. "\""
  os.execute(cmd)
end

local function calculate_auto_scale(sprite_width, sprite_height)
  local target_width = 1920
  local target_height = 1080
  local scale_width = target_width / sprite_width
  local scale_height = target_height / sprite_height
  return math.min(scale_width, scale_height)
end

local function build_ffmpeg_command(frame_dir, output_path, fps, preset, crf, pixel_format, scale, audio_enabled, audio_path)
  local cmd = "ffmpeg -y "
  
  -- Input frames - use %04d for proper Windows escaping
  cmd = cmd .. "-framerate " .. fps .. " -i \"" .. frame_dir .. "\\frame_%04d.png\" "
  
  -- Build filter chain
  local filters = {}
  
  -- Scale filter if needed - use nearest neighbor for pixel art
  if scale ~= 1 then
    table.insert(filters, "scale=trunc(iw*" .. scale .. "/2)*2:trunc(ih*" .. scale .. "/2)*2:flags=neighbor")
  end
  
  -- Pixel format
  table.insert(filters, "format=" .. pixel_format)
  
  if #filters > 0 then
    cmd = cmd .. "-vf \"" .. table.concat(filters, ",") .. "\" "
  end
  
  -- Video codec settings
  cmd = cmd .. "-c:v libx264 "
  cmd = cmd .. "-preset " .. preset .. " "
  cmd = cmd .. "-crf " .. crf .. " "
  
  -- Audio handling
  if audio_enabled and audio_path ~= "" then
    cmd = cmd .. "-i \"" .. audio_path .. "\" "
    cmd = cmd .. "-c:a aac "
    cmd = cmd .. "-shortest "
  else
    cmd = cmd .. "-an "
  end
  
  -- MP4 output flags for compatibility
  cmd = cmd .. "-movflags +faststart "
  
  -- Output file - ensure proper quoting
  cmd = cmd .. "\"" .. output_path .. "\""
  
  return cmd
end

local function export_to_mp4(sprite, settings, output_file)
  -- Validate settings
  local fps = tonumber(settings.fps) or 24
  local preset = settings.preset
  local crf = settings.crf
  local pixel_format = settings.pixelFormat
  local scale = tonumber(settings.scale) or 1
  local audio_enabled = settings.audioEnabled
  local audio_path = settings.audioPath
  local loop_count = tonumber(settings.loopCount) or 1
  
  print("[FFMPEG Export] Starting export with settings:")
  print("[FFMPEG Export]   FPS: " .. fps)
  print("[FFMPEG Export]   Preset: " .. preset)
  print("[FFMPEG Export]   CRF: " .. crf)
  print("[FFMPEG Export]   Output: " .. output_file)
  
  -- Get temp directory
  local temp_dir = os.getenv("TEMP") or os.getenv("TMP")
  if not temp_dir then
    show_error(error_messages.temp_dir_not_found)
    return
  end
  print("[FFMPEG Export] Temp directory: " .. temp_dir)
  
  -- Create unique export directory
  local frame_dir = temp_dir .. "\\aseprite_export_" .. os.time()
  local mkdir_cmd = "mkdir \"" .. frame_dir .. "\""
  print("[FFMPEG Export] Creating frame directory: " .. frame_dir)
  
  local success = os.execute(mkdir_cmd)
  if success ~= 0 and success ~= true then
    show_error(error_messages.temp_dir_creation_failed)
    return
  end
  print("[FFMPEG Export] Frame directory created successfully")
  
  -- Export sprite frames as PNG sequence
  local frame_pattern = frame_dir .. "\\frame_%04d.png"
  print("[FFMPEG Export] Exporting sprite frames to: " .. frame_pattern)
  print("[FFMPEG Export] Total frames in sprite: " .. #sprite.frames)
  
  local export_success, export_error = pcall(function()
    -- Export each frame individually, repeated for loop count
    local frame_number = 0
    for loop = 1, loop_count do
      for frame_idx = 1, #sprite.frames do
        local frame_file = string.format(frame_dir .. "\\frame_%04d.png", frame_number)
        print("[FFMPEG Export] Exporting frame " .. frame_number .. " (loop " .. loop .. ") to: " .. frame_file)
        
        -- Create an image and draw the specific frame
        local image = Image(sprite.width, sprite.height, sprite.colorMode)
        image:drawSprite(sprite, frame_idx)
        
        -- Save the image
        image:saveAs{
          filename = frame_file,
          palette = sprite.palettes[1]
        }
        
        frame_number = frame_number + 1
      end
    end
  end)
  
  if not export_success then
    local error_msg = error_messages.sprite_frame_export_failed .. "\nDetails: " .. tostring(export_error)
    show_error(error_msg)
    cleanup_temp_dir(frame_dir)
    return
  end
  print("[FFMPEG Export] Sprite frames exported successfully")
  
  -- Build FFMPEG command
  print("[FFMPEG Export] Building FFMPEG command...")
  local ffmpeg_cmd = build_ffmpeg_command(frame_dir, output_file, fps, preset, crf, pixel_format, scale, audio_enabled, audio_path)
  print("[FFMPEG Export] Command: " .. ffmpeg_cmd)
  
  -- Execute FFMPEG - write to batch file for better handling of paths with spaces
  print("[FFMPEG Export] Running FFMPEG, please wait...")
  
  local batch_file = frame_dir .. "\\run_ffmpeg.bat"
  local batch_handle = io.open(batch_file, "w")
  if not batch_handle then
    show_error(error_messages.batch_file_creation_failed)
    cleanup_temp_dir(frame_dir)
    return
  end
  
  -- Escape % for batch files by simple character replacement
  local batch_cmd = ""
  for i = 1, #ffmpeg_cmd do
    local char = ffmpeg_cmd:sub(i, i)
    if char == "%" then
      batch_cmd = batch_cmd .. "%%"
    else
      batch_cmd = batch_cmd .. char
    end
  end
  
  batch_handle:write("@echo off\n")
  batch_handle:write("chcp 65001 >nul\n")  -- Set UTF-8 encoding
  batch_handle:write(batch_cmd .. "\n")
  batch_handle:write("echo.\n")
  batch_handle:write("echo FFMPEG completed. Check output above for any errors.\n")
  -- batch_handle:write("pause\n")
  batch_handle:close()
  
  print("[FFMPEG Export] Batch file created: " .. batch_file)
  local result = os.execute("\"" .. batch_file .. "\"")
  print("[FFMPEG Export] FFMPEG returned code: " .. tostring(result) .. " (type: " .. type(result) .. ")")
  
  -- Cleanup temp files
  print("[FFMPEG Export] Cleaning up temporary files...")
  cleanup_temp_dir(frame_dir)
  
  -- Check if output file was created (more reliable than checking return code)
  print("[FFMPEG Export] Checking if output file exists: " .. output_file)
  local file_check = io.open(output_file, "r")
  local file_exists = file_check ~= nil
  if file_check then io.close(file_check) end
  
  if file_exists and (result == 0 or result == true or result == nil) then
    local success_msg = "Export successful!\nSaved to: " .. output_file
    print("[FFMPEG Export] SUCCESS: " .. success_msg)
    app.alert(success_msg)
  else
    local error_msg = error_messages.ffmpeg_not_installed .. "\n\nFFMPEG Command:\n" .. ffmpeg_cmd
    show_error(error_msg)
  end
end

local function show_export_dialog()
  print("[FFMPEG Export] Dialog opened")
  local sprite = app.activeSprite
  
  if not sprite then
    show_error(error_messages.no_active_sprite)
    return
  end
  print("[FFMPEG Export] Active sprite: " .. sprite.filename)

  -- Get sprite directory and name
  local sprite_path = sprite.filename
  local sprite_dir = sprite_path:match("^(.+)[/\\][^/\\]+$") or ""
  if sprite_dir == "" then
    sprite_dir = os.getenv("USERPROFILE") .. "\\Desktop"
  end
  
  local sprite_name = sprite_path:match("([^/\\]+)$"):gsub("%..*", "")

  -- Create main dialog with file and options
  local dialog = Dialog { title = "Export to MP4" }

  dialog:separator { text = "Output File" }
  dialog:entry { id = "output", label = "Output Path & Filename:", text = sprite_dir .. "\\" .. sprite_name .. ".mp4" }
  
  dialog:separator { text = "Video Options" }
  dialog:number { id = "fps", label = "FPS:", text = "24" }
  dialog:combobox { id = "preset", label = "Encoding Preset:", options = { "ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow" }, option = "medium" }
  dialog:label { text = "Quality (CRF 0=lossless, increase to reduce mp4 size)" }
  dialog:combobox { id = "crf", label = "CRF:", options = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "12", "15", "18", "20", "23", "28" }, option = "0" }
  
  dialog:separator { text = "Advanced" }
  dialog:combobox { id = "pixelFormat", label = "Pixel Format:", options = { "yuv420p", "yuv422p", "yuv444p" }, option = "yuv420p" }
  dialog:slider { id = "loopCount", label = "Loop Count:", min = 1, max = 100, value = 5 }
  --dialog:label { id = "durationDisplay", text = "Video duration: 0.00s" }
  dialog:number { id = "scale", label = "Scale (1=original):", text = "1" }
  dialog:button { id = "autoScale", text = "Auto Scale to 1920:1080" }
  
  dialog:separator { text = "Audio" }
  dialog:check { id = "audioEnabled", label = "Include Audio", selected = false }
  dialog:entry { id = "audioPath", label = "Audio File Path:", text = "" }
  
  dialog:separator()
  dialog:button { id = "ok", text = "Export" }
  dialog:button { id = "cancel", text = "Cancel" }

  -- Apply auto-scale by default
  local scale_factor = calculate_auto_scale(sprite.width, sprite.height)
  dialog:modify { id = "scale", text = string.format("%.2f", scale_factor) }
  print("[FFMPEG Export] Default auto scale applied: sprite " .. sprite.width .. "x" .. sprite.height .. " -> scale factor: " .. string.format("%.2f", scale_factor))

  -- Modal dialog loop
  repeat
    dialog:show()
    
    if dialog.data.ok or dialog.data.cancel then
      break
    end
    
    if dialog.data.autoScale then
      -- Calculate auto scale based on sprite dimensions
      local scale_factor = calculate_auto_scale(sprite.width, sprite.height)
      
      -- Update the scale field
      dialog:modify { id = "scale", text = string.format("%.2f", scale_factor) }
      
      print("[FFMPEG Export] Auto scale calculated: sprite " .. sprite.width .. "x" .. sprite.height .. " -> scale factor: " .. string.format("%.2f", scale_factor))
    end
  until dialog.data.ok or dialog.data.cancel

  if dialog.data.ok then
    local output_file = dialog.data.output
    if output_file == "" then
      show_error(error_messages.output_file_not_specified)
      return
    end
    print("[FFMPEG Export] Starting export to: " .. output_file)
    export_to_mp4(sprite, dialog.data, output_file)
  else
    print("[FFMPEG Export] Export cancelled by user")
  end
end

-- Run the dialog when script executes
show_export_dialog()
