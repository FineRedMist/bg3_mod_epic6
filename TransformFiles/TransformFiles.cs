using System;
using System.IO;
using System.Collections.Generic;
using System.Text.Json;
using System.Runtime.CompilerServices;

static class TransformFiles
{
    static Dictionary<string, string> transforms = new Dictionary<string, string>();

    static int Main(string[] args)
    {
        if (args.Length < 3)
        {
            Console.WriteLine("Usage: TransformFiles <path> <old_name> <new_name>");
            return 1;
        }

        string path = args[0];
        string oldName = args[1];
        string newName = args[2];

        if (!Directory.Exists(path))
        {
            Console.WriteLine($"Error: The directory '{path}' does not exist.");
            return 1;
        }

        DirectoryInfo dirInfo = new DirectoryInfo(path);
        path = dirInfo.FullName;

        if (!LoadTransforms(Path.Combine(path, "Transform.json")))
        {
            return 1;
        }

        transforms[oldName] = newName;

        RemapGuidIDs(path);

        foreach (var transform in transforms)
        {
            Console.WriteLine($"Transforming '{transform.Key}' to '{transform.Value}'");
        }

        return ProcessFiles(path, transforms);
    }

    static string Replace(this string input, Dictionary<string, string> transforms)
    {
        foreach (var transform in transforms)
        {
            input = input.Replace(transform.Key, transform.Value, StringComparison.Ordinal);
        }
        return input;
    }

    static void UpdateFileContents(string filePath, Dictionary<string, string> transforms)
    {
        try
        {
            string content = File.ReadAllText(filePath);
            string updatedContent = content.Replace(transforms);
            File.WriteAllText(filePath, updatedContent);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error updating file '{filePath}': {ex.Message}");
        }
    }

    static string RenameTransformFile(string filePath, Dictionary<string, string> transforms)
    {
        string directory = Path.GetDirectoryName(filePath)!;
        string fileName = Path.GetFileName(filePath)!;
        bool isDir = Directory.Exists(filePath);
        if (!isDir)
        {
            UpdateFileContents(filePath, transforms);
        }
        string newFileName = fileName.Replace(transforms);
        string newFilePath = Path.Combine(directory, newFileName);
        if(!newFileName.Equals(fileName, StringComparison.Ordinal))
        {
            if (isDir)
            {
                Directory.Move(filePath, newFilePath);
            }
            else
            {
                File.Move(filePath, newFilePath);

            }
        }

        return newFilePath;
    }

    static int ProcessFiles(string path, Dictionary<string, string> transforms)
    {
        foreach (var file in Directory.GetFileSystemEntries(path, "*.*", SearchOption.TopDirectoryOnly))
        {
            string newFilePath = RenameTransformFile(file, transforms);
            if (newFilePath != file)
            {
                Console.WriteLine($"Renamed '{file}' to '{newFilePath}'");
            }
            if(Directory.Exists(newFilePath))
            {
                ProcessFiles(newFilePath, transforms);
            }
        }
        return 0;
    }

    static void RemapGuidIDs(string path)
    {
        foreach (var file in Directory.GetFiles(path, "*.lsf.lsx", SearchOption.AllDirectories))
        {
            string baseFileName = Path.GetFileNameWithoutExtension(Path.GetFileNameWithoutExtension(file));
            Guid fileGuid;
            if (!Guid.TryParse(baseFileName, out fileGuid))
            {
                continue;
            }

            transforms[baseFileName] = Guid.NewGuid().ToString();
        }
    }
    static bool LoadTransforms(string path)
    {
        if (!File.Exists(path))
        {
            Console.WriteLine($"Error: Transform file '{path}' does not exist.");
            return false;
        }

        var content = File.ReadAllText(path);
        try
        {
            transforms = JsonSerializer.Deserialize<Dictionary<string, string>>(content) ?? transforms;
        }
        catch (JsonException ex)
        {
            Console.WriteLine($"Error parsing transform file: {ex.Message}");
            return false;
        }
        return true;
    }
}