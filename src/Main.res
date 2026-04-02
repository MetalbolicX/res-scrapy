let main: unit => promise<unit> = async () => {
  let config = Cli.parse()
  Console.log2("Remove for later", config)

  let html = await StdIn.readFromStdin()
  Console.log(html)
}

await main()
