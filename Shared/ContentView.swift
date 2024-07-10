import SwiftUI

struct Address: Identifiable, Decodable {
    let id = UUID()
    let endereco: String
    let cidade: String
    let estado: String
    let zip: String?
    let servico: String
    let frequencia: String

    private enum CodingKeys: String, CodingKey {
        case endereco, cidade, estado, zip, servico, frequencia
    }
}

struct ResponseData: Decodable {
    let enderecos: [Address]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let enderecosList = try? container.decode([Address].self, forKey: .enderecos) {
            self.enderecos = enderecosList
        } else if let enderecosDict = try? container.decode([String: Address].self, forKey: .enderecos) {
            self.enderecos = Array(enderecosDict.values)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .enderecos, in: container, debugDescription: "Formato de dados inesperado.")
        }
    }

    private enum CodingKeys: String, CodingKey {
        case enderecos
    }
}

struct ContentView: View {
    @State private var addresses: [Address] = []
    @State private var groupedAddresses: [String: [Address]] = [:]
    @State private var showActionSheet = false
    @State private var selectedAddress: Address?
    @State private var selectedDate = Date()
    @State private var showDatePicker = false // Adicione a variável de estado para controlar a exibição do DatePicker
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                // Adicione um botão para abrir o DatePicker
                Button(action: {
                    showDatePicker.toggle()
                }) {
                    Text("Select a date")
                }
                .sheet(isPresented: $showDatePicker) {
                    DatePicker("Select a date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .onChange(of: selectedDate) { date in
                            fetchAddresses(for: date) { result in
                                switch result {
                                case .success(let fetchedAddresses):
                                    self.addresses = fetchedAddresses
                                    self.groupAddressesByCity()
                                    // Feche o DatePicker ao selecionar uma data
                                    showDatePicker = false
                                case .failure(let error):
                                    print("Failed to fetch addresses: \(error.localizedDescription)")
                                }
                            }
                        }
                        .padding()
                }
                
                // Adicione este código para mostrar a data selecionada
                Text("Selected Date: \(selectedDate, formatter: dateFormatter)")
                    .padding()

                List {
                    ForEach(groupedAddresses.keys.sorted(), id: \.self) { city in
                        Section(header: Text(city)) {
                            ForEach(groupedAddresses[city]!) { address in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .foregroundColor(.clear)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedAddress = address
                                            showActionSheet = true
                                        }
                                    VStack(alignment: .leading) {
                                        Text(address.endereco)
                                        Spacer() // Adicionando um Spacer para garantir que o VStack ocupe o máximo de espaço possível
                                    }
                                    .padding(.top, 10) // Adiciona padding adicional no topo
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lista de Endereços")
            .onAppear {
                fetchAddresses(for: selectedDate) { result in
                    switch result {
                    case .success(let fetchedAddresses):
                        self.addresses = fetchedAddresses
                        self.groupAddressesByCity()
                    case .failure(let error):
                        print("Failed to fetch addresses: \(error.localizedDescription)")
                    }
                }
            }
            .actionSheet(isPresented: $showActionSheet) {
                ActionSheet(title: Text("Escolha uma opção"), buttons: [
                    .default(Text("Take a picture")) {
                        print("Opção 1 selecionada para \(selectedAddress?.endereco ?? "")")
                    },
                    .default(Text("Maps")) {
                        print("Opção 2 selecionada para \(selectedAddress?.endereco ?? "")")
                    },
                    .cancel()
                ])
            }
        }
    }
    
    private func groupAddressesByCity() {
        groupedAddresses = Dictionary(grouping: addresses, by: { $0.cidade })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
}()


func fetchAddresses(for date: Date, completion: @escaping (Result<[Address], Error>) -> Void) {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let dateString = dateFormatter.string(from: date)
    
    guard let url = URL(string: "https://pwms.com.br/backends/invoices-v3/public/buscarRotaGeraisEdicaoV2?data=\(dateString)") else {
        print("URL inválida.")
        return
    }

    let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
        if let error = error {
            print("Erro ao realizar requisição: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("Erro de resposta do servidor.")
            let responseError = NSError(domain: "", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Erro de resposta do servidor."])
            completion(.failure(responseError))
            return
        }

        guard let mimeType = httpResponse.mimeType, mimeType == "application/json",
              let data = data else {
            print("Formato de dados inesperado ou vazio.")
            let formatError = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Formato de dados inesperado ou vazio."])
            completion(.failure(formatError))
            return
        }

        do {
            print("dateString: \(dateString)")
            print("URL: \(url)")
            
            let jsonString = String(data: data, encoding: .utf8) ?? "Dados inválidos"
            //print("Dados JSON recebidos: \(jsonString)")
            
            let responseData = try JSONDecoder().decode(ResponseData.self, from: data)
            //print("Dados JSON decodificados com sucesso: \(responseData.enderecos)")
            completion(.success(responseData.enderecos))
        } catch {
            print("Erro ao decodificar dados JSON: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }

    task.resume()
}
