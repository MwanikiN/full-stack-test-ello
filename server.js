const { ApolloServer, gql } = require("apollo-server-express");
const express = require("express");
const fs = require("fs");
const path = require("path");

const booksFolder = path.join(__dirname, "resources");

const typeDefs = gql`
  type Page {
    pageIndex: Int
    content: String
  }

  type Token {
    position: [Int]
    value: String
  }

  type PageWithTokens {
    pageIndex: Int
    content: String
    tokens: [Token]
  }

  type Book {
    title: String
    author: String
    pages: [PageWithTokens]
  }

  type Query {
    getBook(title: String!): Book
  }
`;

const resolvers = {
  Query: {
    getBook: (_, { title }) => {
      const bookFilePath = path.join(booksFolder, `${title}.json`);

      try {
        const bookData = JSON.parse(fs.readFileSync(bookFilePath, "utf8"));
        return bookData;
      } catch (error) {
        throw new Error("Book not found");
      }
    },
  },
};

async function startApolloServer() {
  const server = new ApolloServer({ typeDefs, resolvers });
  await server.start();

  const app = express();

  server.applyMiddleware({ app });

  app.listen({ port: 4000 }, () =>
    console.log(`Server is running on http://localhost:4000${server.graphqlPath}`)
  );
}

startApolloServer().catch((error) => {
  console.error("Error starting Apollo Server:", error);
});
