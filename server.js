/*sets up a GraphQL server using Apollo Server and Express. 
The server provides a single GraphQL query for retrieving book
 data from JSON files stored in a "resources" folder based on the book's title. */

const { ApolloServer, gql } = require("apollo-server-express");
const express = require("express");
const fs = require("fs");
const path = require("path");

/* Define the folder where book data JSON files are stored */
const booksFolder = path.join(__dirname, "resources");

/* Define GraphQL schema using gql template literal */
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

/* Define resolver functions for the Query type */
const resolvers = {
  Query: {
    getBook: (_, { title }) => {
      /* Construct the file path for the requested book */
      const bookFilePath = path.join(booksFolder, `${title}.json`);

      try {
        /* Read and parse the book data from the JSON file */
        const bookData = JSON.parse(fs.readFileSync(bookFilePath, "utf8"));
        return bookData; // Return the book data if found
      } catch (error) {
        throw new Error("Book not found"); // Throw an error if the book is not found
      }
    },
  },
};

/* Function to start the Apollo Server and Express application */
async function startApolloServer() {
  const server = new ApolloServer({ typeDefs, resolvers }); // Create an Apollo Server instance
  await server.start(); // Start the server

  const app = express(); // Create an Express application

  server.applyMiddleware({ app }); // Integrate Apollo Server with Express

  app.listen({ port: 4000 }, () =>
    console.log(`Server is running on http://localhost:4000${server.graphqlPath}`)
  ); // Start the Express server and log the server URL
}

/* Start the Apollo Server and handle errors */
startApolloServer().catch((error) => {
  console.error("Error starting Apollo Server:", error);
});
