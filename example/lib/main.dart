import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mopro_flutter_bindings/src/rust/third_party/circom_prover_bindings.dart';
import 'package:mopro_flutter_bindings/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  CircomProofResult? _circomProofResult;
  bool? _circomValid;
  bool isProving = false;
  Exception? _error;
  late TabController _tabController;

  // Controllers to handle user input
  final TextEditingController _controllerA = TextEditingController();
  final TextEditingController _controllerB = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controllerA.text = "5";
    _controllerB.text = "3";
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildCircomTab() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isProving) const CircularProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_error.toString()),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _controllerA,
              decoration: const InputDecoration(
                labelText: "Public input `a`",
                hintText: "For example, 5",
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _controllerB,
              decoration: const InputDecoration(
                labelText: "Private input `b`",
                hintText: "For example, 3",
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: OutlinedButton(
                  onPressed: () async {
                    if (_controllerA.text.isEmpty ||
                        _controllerB.text.isEmpty ||
                        isProving) {
                      return;
                    }
                    setState(() {
                      _error = null;
                      isProving = true;
                    });

                    FocusManager.instance.primaryFocus?.unfocus();
                    CircomProofResult? proofResult;
                    try {
                      var inputs =
                          '{"a":["${_controllerA.text}"],"b":["${_controllerB.text}"]}';
                      final zkeyPath = await copyAssetToFileSystem(
                        'assets/multiplier2_final.zkey',
                      );
                      final graphPath = await copyAssetToFileSystem(
                        'assets/multiplier2.bin',
                      );
                      proofResult = await circomProve(
                        graphPath: graphPath,
                        inputs: inputs,
                        zkeyPath: zkeyPath,
                      );
                    } on Exception catch (e) {
                      print("Error: $e");
                      proofResult = null;
                      setState(() {
                        _error = e;
                      });
                    }

                    if (!mounted) return;

                    setState(() {
                      isProving = false;
                      _circomProofResult = proofResult;
                    });
                  },
                  child: const Text("Generate Proof"),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: OutlinedButton(
                  onPressed: () async {
                    if (_controllerA.text.isEmpty ||
                        _controllerB.text.isEmpty ||
                        isProving) {
                      return;
                    }
                    setState(() {
                      _error = null;
                      isProving = true;
                    });

                    FocusManager.instance.primaryFocus?.unfocus();
                    bool? valid;
                    try {
                      var proofResult = _circomProofResult;
                      final zkeyPath = await copyAssetToFileSystem(
                        'assets/multiplier2_final.zkey',
                      );
                      valid = await verifyCircomProof(
                        zkeyPath: zkeyPath,
                        proofResult: proofResult!,
                        proofLib: ProofLib.arkworks,
                      ); // DO NOT change the proofLib if you don't build for rapidsnark
                    } on Exception catch (e) {
                      print("Error: $e");
                      valid = false;
                      setState(() {
                        _error = e;
                      });
                    } on TypeError catch (e) {
                      print("Error: $e");
                      valid = false;
                      setState(() {
                        _error = Exception(e.toString());
                      });
                    }

                    if (!mounted) return;

                    setState(() {
                      isProving = false;
                      _circomValid = valid;
                    });
                  },
                  child: const Text("Verify Proof"),
                ),
              ),
            ],
          ),
          if (_circomProofResult != null)
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Proof is valid: ${_circomValid ?? false}'),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Proof inputs: ${_circomProofResult?.inputs ?? ""}',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Proof: ${_circomProofResult?.proof ?? ""}'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter App With MoPro'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [Tab(text: 'Circom')],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [_buildCircomTab()],
        ),
      ),
    );
  }
}

/// Copies an asset to a file and returns the file path
Future<String> copyAssetToFileSystem(String assetPath) async {
  final byteData = await rootBundle.load(assetPath);
  final directory = await getApplicationDocumentsDirectory();
  final filename = assetPath.split('/').last;
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(byteData.buffer.asUint8List());
  return file.path;
}
