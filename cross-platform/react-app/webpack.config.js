/*---------------------------------------------------------------------------------------------
* Copyright (c) Bentley Systems, Incorporated. All rights reserved.
* See LICENSE.md in the project root for license terms and full copyright notice.
*--------------------------------------------------------------------------------------------*/

const path = require("path");
const webpack = require("webpack");
const TerserPlugin = require('terser-webpack-plugin');

module.exports = (env) => {
  return getConfig(env);
};

function getConfig(env) {
  // set sourcedir if not specified in arguments.
  if (!env.sourcedir)
    env.sourcedir = "./";

  // unless specified with NODE_ENV=development, create a production build.
  const devMode = process.env.NODE_ENV === "development";

  if (!env.outdir)
    env.outdir = "./lib/module" + (devMode ? "/prod" : "/dev");

  // get the directory for the bundle.
  const bundleDirectory = path.resolve(env.sourcedir, env.outdir);

  // this is the "barrel" file of the module, which imports all of the sources.
  const bundleEntry = env.entry;

  // name of the output bundle.
  const bundleName = env.bundlename;

  const webConfig = {
    mode: devMode ? "development" : "production",
    entry: bundleEntry,
    output: {
      libraryTarget: "commonjs2",
      library: bundleName,
      path: bundleDirectory,
      pathinfo: true,
    },
    target: "node",
    devtool: devMode ? "cheap-module-source-map" : undefined,
    // WebPack defaults to using the esm version of json5. The alias below forces it to use cjs.
    // See: https://github.com/json5/json5/issues/240
    resolve: {
      alias: {
        json5: 'json5/lib/index.js',
      }
    },
    // The module rules below cause it to skip certain things. These are things that we
    // don't really use, but trigger exceptions at run-time in their startup
    // initialization.
    module: {
      // don't parse @bentley/imodeljs-native/NativeLibrary.js,
      // we don't need to pull in the Native here as it gets loaded by the runtime
      // via (process as any)._linkedBinding("iModelJsNative")
      noParse: [/NativeLibrary.js$/],
      rules: [
        {
          test: /formidable(\\|\/).*js$/,
          use: 'null-loader'
        },
        // {
        //   test: /backend-itwin-client/,
        //   use: 'null-loader'
        // },
        // {
        //   test: /ElectronUtils\.js$/,
        //   use: 'null-loader'
        // },
        // {
        //   test: /ElectronIpcTransport\.js$/,
        //   use: 'null-loader'
        // },
        // {
        //   test: /BackendAuthorizationClient\.js$/,
        //   use: 'null-loader'
        // },
        // {
        //   test: /BlobDaemon\.js$/,
        //   use: 'null-loader'
        // },
        // {
        //   test: /xunit\.js$/,
        //   use: 'null-loader'
        // },
        // {
        //   test: /bunyan/,
        //   use: 'null-loader'
        // },
        // {
        //   test: /@azure/,
        //   use: 'null-loader'
        // },
        // {
        //   test: /IModelBankCloudEnv\.js$/,
        //   use: 'null-loader'
        // },
        // {
        //   test: /DevTools\.js$/,
        //   use: 'null-loader'
        // },
        // {
        //   test: /DesktopAuthorizationClient\.js$/,
        //   use: 'null-loader'
        // },
        // {
        //   test: /oidc-signin-tool/,
        //   use: 'null-loader'
        // },
        // {
        //   test: /AzCopy\.js$/,
        //   use: 'null-loader'
        // },
      ]
    },
    externals: {
      "electron": "electron",
      "fs": "fs",
    },
    stats: {
      warnings: false
    },
    node: {
      __dirname: false,
      __filename: false,
    },
    plugins: [
      new webpack.DefinePlugin({ "global.GENTLY": false, "process.version": "'v10.9.0'" }),
      // new webpack.ProvidePlugin({}),
      // new webpack.EnvironmentPlugin({})
    ],
    optimization: devMode ? undefined : {
      minimize: true,
      minimizer: [new TerserPlugin({
        terserOptions: {
          keep_classnames: /AbortSignal/,
          keep_fnames: /AbortSignal/
        }
      })],
    }
  };

  return webConfig;
}
