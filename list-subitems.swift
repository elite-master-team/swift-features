//
//  ContentView.swift
//  Shared
//
//  Created by User on 7/1/24.
//

import SwiftUI

struct Item: Identifiable {
    let id = UUID()
    let title: String
    let subitems: [String]
}

struct ContentView: View {
    let items: [Item] = [
            Item(title: "Item 1", subitems: ["Subitem 1.1", "Subitem 1.2"]),
            Item(title: "Item 2", subitems: ["Subitem 2.1", "Subitem 2.2", "Subitem 2.3"]),
            Item(title: "Item 3", subitems: ["Subitem 3.1"])
        ]
    
    
    var body: some View {
            NavigationView {
                List(items) { item in
                    Section(header: Text(item.title)) {
                        ForEach(item.subitems, id: \.self) { subitem in
                            Text(subitem)
                        }
                    }
                }
                .navigationTitle("Lista de Itens")
            }
        }
    
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        
        ContentView()
    }
}
