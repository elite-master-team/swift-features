import SwiftUI

struct Address: Identifiable, Decodable {
    let id = UUID()
    let endereco: String
    let cidade: String
    let estado: String
    let zip: String
    let servico: String
    let frequencia: String

    private enum CodingKeys: String, CodingKey {
        case endereco, cidade, estado, zip, servico, frequencia
    }
}

struct ResponseData: Decodable {
    let enderecos: [Address]
}

struct ContentView: View {
    @State private var addresses: [Address] = []
    @State private var groupedAddresses: [String: [Address]] = [:]
    @State private var showActionSheet = false
    @State private var selectedAddress: Address?

    var body: some View {
        NavigationView {
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
//                                    Text("Serviço: \(address.servico)")
                                    Text(address.endereco)
                                    Spacer() // Adicionando um Spacer para garantir que o VStack ocupe o máximo de espaço possível
                                }
                                .padding(.top, 10) // Adiciona padding adicional no topo
//                                .background(Color.white)
//                                .cornerRadius(8)
//                                .shadow(radius: 2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lista de Endereços")
            .onAppear {
                fetchAddresses { result in
                    switch result {
                    case .success(let fetchedAddresses):
                        print("----> sucesso")
                        self.addresses = fetchedAddresses
                        self.groupAddressesByCity()
                        print("==> " + fetchedAddresses.map { "\($0.endereco), \($0.cidade), \($0.estado), \($0.zip)" }.joined(separator: "\n"))
                    case .failure(let error):
                        print("-----> Failed to fetch addresses: \(error.localizedDescription)")
                    }
                }
            }
            .actionSheet(isPresented: $showActionSheet) {
                ActionSheet(title: Text("Escolha uma opção"), buttons: [
                    .default(Text("Take a picure")) {
                        print("Opção 1 selecionada para \(selectedAddress?.endereco ?? "")")
                    },
                    .default(Text("Delete")) {
                        print("Opção 2 selecionada para \(selectedAddress?.endereco ?? "")")
                    },
                    .default(Text("Maps")) {
                        print("Opção 3 selecionada para \(selectedAddress?.endereco ?? "")")
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

func fetchAddresses(completion: @escaping (Result<[Address], Error>) -> Void) {
    guard let url = URL(string: "https://pwms.com.br/backends/invoices-v3/public/buscarRotaGeraisEdicaoV2?data=2024-07-7") else {
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
            let responseData = try JSONDecoder().decode(ResponseData.self, from: data)
            print("Dados JSON recebidos e decodificados com sucesso: \(responseData.enderecos)")
            completion(.success(responseData.enderecos))
        } catch {
            print("Erro ao decodificar dados JSON: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }

    task.resume()
}
