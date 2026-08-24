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
  command_type(15, "Seçiniz"),
];

// Aksiyon (process) seçildiğinde kullanıcıya gösterilen açıklama --
// "Toggle" ile "Toggle (Max)" gibi birbirine yakın isimlerin farkını
// netleştirmek için.
const Map<int, String> processDescriptions = {
  0: "Basıldığında lamba son parlaklık seviyesine açılır.",
  1: "Basıldığında lamba kapanır.",
  2: "Basıldığında açık/kapalı arasında geçiş yapar.",
  3: "Basılı tutuldukça parlaklık yukarı kayar.",
  4: "Basılı tutuldukça parlaklık aşağı kayar.",
  5: "Basıldığında sabit bir parlaklık seviyesine gider.",
  6: "Basıldığında maksimum parlaklığa gider.",
  7: "Basıldığında minimum parlaklığa gider.",
  8: "Hareket algılanınca maksimuma çıkar, hareket bitince kapanır.",
  9: "Basıldığında maksimum parlaklık ile kapalı arasında geçiş yapar.",
  10: "Hareket algılanınca maksimuma çıkar, hareket bitince minimuma iner.",
  11: "Basılı tutuldukça dimler; her basılı tutuşta yön değişir (yukarı/aşağı sırayla).",
};
