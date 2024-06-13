import Foundation
import ProxyWorldUtility
import KwiftExtension
import ArgumentParser
import Precondition
import SystemPackage
import SystemUp
import SystemFileManager
import Command

struct UpdateGeodb: AsyncParsableCommand {

  @Argument
  var directory: FilePath?

  enum UpdateError: Error {
    case readClashOutput
  }

  func run() async throws {
    let configurationDirectory = try directory ?? defaultClashConfigDir()
    let dbFilePath = try defaultGeoDBPath(rootPath: configurationDirectory)
    print("Dest MMDB path: \(dbFilePath)")
    if SystemFileManager.fileExists(atPath: .absolute(dbFilePath)) {
      print("Remove old MMDB file")
      try FileSyscalls.unlink(.absolute(dbFilePath)).get()
    }
    let rootTemp: FilePath = .init(PosixEnvironment.get(key: "TMPDIR") ?? "/tmp")
    let template = rootTemp.appending("temp.XXXXXX")
    let emptyConfig = """
    mode: direct
    """
    let (fd, path) = try SystemCall.createTemporaryFile(template: template.string).get()
    try fd.closeAfter {
      _ = try fd.writeAll(emptyConfig.utf8)
    }
    print("Use temp config:", path.string)

    let exe = Clash(configurationDirectory: configurationDirectory.string, configurationFile: path.string, test: true)
    var command = Command(executable: "clash", arguments: exe.arguments)
    command.defaultIO = .null
    command.stdout = .makePipe
    var process = try command.spawn()
    defer {
      print("Clash exit status:", try! process.wait())
    }

    let stream = try FileStream.open(process.pipes.takeStdOut().unwrap("process's stdout is not set properly").local, mode: .read()).get()
    defer { _ = stream.close() }
    try withUnsafeTemporaryAllocation(of: CChar.self, capacity: 4096) { buffer in
      guard stream.getLine(into: buffer) else {
        throw UpdateError.readClashOutput
      }
      let line1 = String(cString: buffer.baseAddress!)
      if line1.contains("start download") {
        print("Start download")
        guard stream.getLine(into: buffer) else {
          throw UpdateError.readClashOutput
        }
        let line2 = String(cString: buffer.baseAddress!)
        if line2.contains("test is successful") {
          print("Download finished")
          if SystemFileManager.fileExists(atPath: .absolute(dbFilePath)) {
            print("I'm sure MMDB is there")
          }
        } else if line2.contains("can't initial MMDB") {
          print("Can't download MMDB")
        } else {
          print("Invalid output line 2:")
          print(line2)
        }
      } else {
        print("Invalid output line 1:")
        print(line1)
      }
      // read to end
      while !stream.isEOF {
        _ = stream.read(into: buffer)
      }
    }
  }

}
