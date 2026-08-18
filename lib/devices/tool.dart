class command_type {
  final int id;
  final String name;

  const command_type(this.id, this.name);
}

const List<command_type> getcommandtype = <command_type>[
  command_type(0, "Lamba"),
  command_type(1, "Gurup"),
  command_type(2, "Senaryo"),
  command_type(3, "Anahtar"),
  command_type(4, "Unknown")
];

const List<command_type> getprocesstype = <command_type>[
  command_type(0, "Last Level"),
  command_type(1, "Off"),
  command_type(2, "Toggle"),
  command_type(3, "Up Dim"),
  command_type(4, "Down Dim"),
  command_type(5, "Arc Power"),
  command_type(6, "Max Level"),
  command_type(7, "Min Level"),
  command_type(8, "Max On/Off (Sens)"),
  command_type(9, "Toggle (Max)"),
  command_type(10, "MxOn/MnOff(Sens)"),
  command_type(11, "Toggle Dim"),
  command_type(12, "."),
  command_type(13, "."),
  command_type(14, "."),
  command_type(15, "Unknown"),
];
