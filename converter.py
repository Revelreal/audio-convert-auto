import os
import argparse
from pydub import AudioSegment
from tqdm import tqdm

def convert_audio_files(source_folder, input_format, output_format, delete_original=False):
    audio_paths = []
    for root, dirs, files in os.walk(source_folder):
        for file in files:
            if file.lower().endswith(f".{input_format.lower()}"):
                audio_paths.append(os.path.join(root, file))

    if not audio_paths:
        print(f"No .{input_format} files found in {source_folder}")
        return

    print(f"Total {input_format.upper()} files found: {len(audio_paths)}")
    print(f"Converting {input_format.upper()} to {output_format.upper()}...")

    converted_count = 0
    failed_files = []
    skipped_files = []
    
    for full_path in tqdm(audio_paths, desc='Converting'):
        try:
            # 获取文件信息
            directory = os.path.dirname(full_path)
            filename = os.path.basename(full_path)
            base_name = os.path.splitext(filename)[0]
            
            # 如果输入输出格式相同，添加后缀
            if input_format.lower() == output_format.lower():
                output_filename = f"{base_name}_converted.{output_format}"
            else:
                output_filename = f"{base_name}.{output_format}"
            
            output_path = os.path.join(directory, output_filename)
            
            # 避免覆盖已存在的文件
            counter = 1
            original_output_path = output_path
            while os.path.exists(output_path):
                if input_format.lower() == output_format.lower():
                    output_filename = f"{base_name}_converted_{counter}.{output_format}"
                else:
                    output_filename = f"{base_name}_{counter}.{output_format}"
                output_path = os.path.join(directory, output_filename)
                counter += 1
            
            # 如果文件被重命名，记录跳过信息
            if counter > 1:
                skipped_files.append((filename, "Output file already exists"))
                continue
            
            # 加载并转换音频
            audio = AudioSegment.from_file(full_path, format=input_format)
            
            # 保存到新的文件路径
            audio.export(output_path, format=output_format)
            
            # 验证新文件是否创建成功
            if os.path.exists(output_path) and os.path.getsize(output_path) > 0:
                converted_count += 1
                
                # 删除原文件（如果需要且格式不同）
                if delete_original and input_format.lower() != output_format.lower():
                    try:
                        os.remove(full_path)
                    except Exception as e:
                        print(f"\n⚠ Converted but failed to delete: {filename}")
            else:
                failed_files.append((filename, "Output file not created"))
                
        except Exception as e:
            failed_files.append((filename, str(e)))
    
    # 显示结果
    print(f"\n{'='*60}")
    print(f"Conversion complete!")
    print(f"Successfully converted: {converted_count}/{len(audio_paths)} files")
    
    if skipped_files:
        print(f"\nSkipped {len(skipped_files)} files (already converted):")
        for file, reason in skipped_files[:5]:  # 只显示前5个
            print(f"  - {file}: {reason}")
        if len(skipped_files) > 5:
            print(f"  ... and {len(skipped_files) - 5} more")
    
    if failed_files:
        print(f"\nFailed to convert {len(failed_files)} files:")
        for file, error in failed_files[:5]:  # 只显示前5个错误
            print(f"  - {file}: {error}")
        if len(failed_files) > 5:
            print(f"  ... and {len(failed_files) - 5} more")
    
    print(f"{'='*60}")

def main():
    parser = argparse.ArgumentParser(description="Convert audio files between formats.")
    parser.add_argument("source_folder", type=str, help="The folder containing audio files to convert.")
    parser.add_argument("input_format", type=str, choices=["mp3", "m4a", "ogg", "flac", "wav"], 
                       help="The audio file format to convert from.")
    parser.add_argument("output_format", type=str, choices=["wav", "mp3", "ogg", "flac"], 
                       help="The audio file format to convert to.")
    parser.add_argument("--delete-original", action="store_true",
                       help="Delete original files after successful conversion (not applied when input=output format)")
    
    args = parser.parse_args()

    convert_audio_files(args.source_folder, args.input_format, args.output_format, args.delete_original)

if __name__ == "__main__":
    main()