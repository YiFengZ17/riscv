# 在 WSL 中运行 RISC-V 汇编

本目录的 `test.s` 是一个 RV64（64 位 RISC-V）Linux 汇编程序：打印 `Hello, RISC-V!`，然后以状态码 0 退出。

## 1. 进入目录

在 Windows PowerShell 中输入：

```powershell
wsl -d Ubuntu-24.04
```

接下来所有命令都在 Ubuntu 终端里执行：

```bash
cd /home/yifeng/projects/risc-v
```

Windows 文件资源管理器也能通过下面的地址查看这些文件：

```text
\\wsl.localhost\Ubuntu-24.04\home\yifeng\projects\risc-v
```

## 2. 编译并运行

```bash
riscv64-linux-gnu-gcc -g -nostdlib -static -no-pie -o test test.s
qemu-riscv64 ./test
```

预期输出：

```text
Hello, RISC-V!
```

紧接着执行以下命令检查退出状态，预期为 `0`：

```bash
echo $?
```

编译命令中：

- `riscv64-linux-gnu-gcc`：生成 RISC-V 程序的交叉编译器。
- `-g`：保留调试信息。
- `-nostdlib`：不链接标准库和默认启动代码；本例自己提供 `_start`。
- `-static -no-pie`：生成静态、非 PIE 可执行文件，便于直接运行和调试。
- `-o test`：输出可执行文件名；`test.s` 是输入的汇编源文件。

修改 `test.s` 后，需要重新编译，再运行。对其他使用相同入口和 Linux 调用约定的独立汇编程序，替换上述源文件名和输出文件名即可。

## 3. 查看机器码

```bash
file ./test
riscv64-linux-gnu-objdump -d ./test
```

`file` 应显示 RISC-V 64 位 ELF，`objdump` 会列出机器指令。

## 4. 单步调试（可选）

在第一个 Ubuntu 终端里进入本目录，运行：

```bash
qemu-riscv64 -g 1234 ./test
```

此时程序会等待 GDB 连接，没有输出是正常的。

再打开一个 Ubuntu 终端，执行：

```bash
cd /home/yifeng/projects/risc-v
gdb-multiarch ./test
```

在 GDB 提示符下依次输入：

```gdb
target remote localhost:1234
display/i $pc
info registers
si
```

常用命令：

| 命令 | 用途 |
|---|---|
| `si` | 执行一条机器指令 |
| `info registers` | 查看寄存器 |
| `x/8i $pc` | 查看当前地址起的 8 条指令 |
| `x/14cb &message` | 查看消息的 14 个字节 |
| `continue` | 继续运行直到退出或断点 |
| `quit` | 退出 GDB |

## 5. 环境与调用约定

已验证的环境：WSL2、Ubuntu 24.04、RISC-V GCC 13.3.0、QEMU 8.2.2、GDB Multiarch 15.1。

如果在其他机器上使用，可以在 Ubuntu 中安装依赖：

```bash
sudo apt update
sudo apt install -y gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu qemu-user gdb-multiarch
```

本例采用 **Linux RISC-V 系统调用约定**：`a7` 放调用号，`a0` 等寄存器放参数，`ecall` 发起调用；64 是 `write`，93 是 `exit`。RARS 的打印整数等调用不能直接照搬。

当前 Ubuntu 是 x86-64，所以需要通过 `qemu-riscv64 ./test` 运行交叉编译后的程序。普通 `gcc` 默认生成 x86-64 程序。

这里使用 QEMU 用户模式运行一个 Linux 程序。以后运行 xv6 或自己的内核，需要使用 `qemu-system-riscv64` 和对应项目的启动配置。
